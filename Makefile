.PHONY: automation-test doctor plan prepare verify build transfer install launch status report
# Pass selectors through the environment; never splice user paths into shell text.
export WORKSPACE GAME CURL_ARCHIVE DEVICE TEAM TRANSPORT INTERFACE REPORT_OUTPUT HUMAN_RESULTS
automation-test:
	uv run --no-project python -m unittest discover -s tests/automation -p 'test_*.py' -v
doctor plan prepare verify build transfer install launch status report:
	uv run --no-project python tools/visirupt.py $@
