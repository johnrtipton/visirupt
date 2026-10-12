#import "CPOriginalStartup.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

static void Save(NSDictionary *report) {
    NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *url = [directory URLByAppendingPathComponent:@"startup-results.json"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&error];
    if (!data || ![data writeToURL:url options:NSDataWritingAtomic error:&error]) NSLog(@"Startup checkpoint failure: %@", error);
}

void CPAttemptOriginalStartup(NSString *modulePath, NSDictionary *loadReport) {
    NSCAssert(NSThread.isMainThread, @"Original desktop entrypoint requires main-thread startup");
    NSMutableDictionary *report = [loadReport mutableCopy];
    report[@"state"] = @"ENTRYPOINT_VALIDATING";
    report[@"original_game_assets_staged"] = @YES;
    report[@"original_engine_and_r6_assets_staged"] = @YES;
    report[@"original_game_archive_assets_staged"] = @YES;
    report[@"original_entrypoint_invocation_attempted"] = @NO;
    report[@"original_entrypoint_returned"] = @NO;
    report[@"original_game_frame_confirmed"] = @NO;
    intptr_t slide = 0;
    const struct mach_header_64 *header = NULL;
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const char *name = _dyld_get_image_name(index);
        if (name && strcmp(name, modulePath.fileSystemRepresentation) == 0) {
            header = (const struct mach_header_64 *)_dyld_get_image_header(index);
            slide = _dyld_get_image_vmaddr_slide(index);
            break;
        }
    }
    BOOL verified = header && header->magic == MH_MAGIC_64 && header->filetype == MH_DYLIB;
    const uintptr_t preferred = 0x100034a78;
    BOOL insideText = NO;
    if (verified) {
        const uint8_t *cursor = (const uint8_t *)(header + 1);
        const uint8_t *end = cursor + header->sizeofcmds;
        for (uint32_t index = 0; index < header->ncmds; index++) {
            if (cursor + sizeof(struct load_command) > end) { verified = NO; break; }
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end-cursor)) { verified = NO; break; }
            if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)cursor;
                if (segment->nsects > (command->cmdsize-sizeof(*segment))/sizeof(struct section_64)) { verified = NO; break; }
                const struct section_64 *section = (const struct section_64 *)(segment+1);
                for (uint32_t j = 0; j < segment->nsects; j++) {
                    if (strncmp(section[j].segname,"__TEXT",16)==0 && strncmp(section[j].sectname,"__text",16)==0 && preferred>=section[j].addr && preferred-section[j].addr+8<=section[j].size) insideText=YES;
                }
            }
            cursor += command->cmdsize;
        }
    }
    uintptr_t runtimeAddress = preferred + slide;
    verified = verified && insideText;
    if (verified) {
        uint32_t words[2]; memcpy(words,(const void *)runtimeAddress,sizeof(words));
        verified = words[0] == 0xa9bd57f6 && words[1] == 0xa9014ff4;
    }
    report[@"entrypoint_preferred_address"] = @"0x100034a78";
    report[@"entrypoint_runtime_address"] = [NSString stringWithFormat:@"0x%llx",(unsigned long long)runtimeAddress];
    report[@"module_slide"] = [NSString stringWithFormat:@"0x%llx",(unsigned long long)slide];
    report[@"entrypoint_bounds_and_first_instructions_verified"] = @(verified);
    if (!verified) { report[@"state"]=@"ENTRYPOINT_VALIDATION_FAILED"; Save(report); return; }
    const char *argument = NSProcessInfo.processInfo.arguments.firstObject.UTF8String;
    char *argv[] = {strdup(argument ?: "CyberpunkEntrypointProbe"),NULL};
    if (!argv[0]) { report[@"state"]=@"ENTRYPOINT_ARGUMENT_ALLOCATION_FAILED"; Save(report); return; }
    report[@"entrypoint_argc"] = @1;
    report[@"entrypoint_argv0"] = @(argv[0]);
    report[@"state"] = @"ENTRYPOINT_CALL_ABOUT_TO_BE_ISSUED";
    report[@"original_entrypoint_invocation_attempted"] = @YES;
    Save(report);
    @try {
        int (*entry)(int,char **) = (int (*)(int,char **))runtimeAddress;
        int result = entry(1,argv);
        report[@"original_game_entrypoint_called"] = @YES;
        report[@"original_entrypoint_returned"] = @YES;
        report[@"entrypoint_return_value"] = @(result);
        report[@"state"] = @"ENTRYPOINT_RETURNED";
        report[@"status"] = @"ORIGINAL_ENTRYPOINT_RETURNED";
    } @catch (NSException *exception) {
        report[@"state"] = @"ENTRYPOINT_OBJECTIVE_C_EXCEPTION";
        report[@"exception_name"] = exception.name;
        report[@"exception_reason"] = exception.reason ?: @"";
        report[@"exception_stack_symbols"] = exception.callStackSymbols;
        NSMutableArray *frames = [NSMutableArray new];
        BOOL entryOnStack = NO;
        for (NSNumber *address in exception.callStackReturnAddresses) {
            uintptr_t pc = address.unsignedLongLongValue;
            if (pc >= runtimeAddress && pc < runtimeAddress+0x80) entryOnStack = YES;
            [frames addObject:[NSString stringWithFormat:@"0x%llx",(unsigned long long)pc]];
        }
        report[@"exception_stack_addresses"] = frames;
        report[@"original_entrypoint_observed_on_exception_stack"] = @(entryOnStack);
        report[@"original_game_entrypoint_called"] = @(entryOnStack);
        // A recorded exception is failure, never successful game startup.
    }
    Save(report);
    free(argv[0]);
}
