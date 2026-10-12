"use strict";
const polls = document.querySelector("#polls-list");
const status = document.querySelector("#polls-status");
function render(data) {
  polls.replaceChildren();
  for (const poll of data.polls) {
    const form = document.createElement("form");
    form.className = "poll";
    const fieldset = document.createElement("fieldset");
    const legend = document.createElement("legend");
    legend.textContent = poll.question;
    fieldset.append(legend);
    for (const option of poll.options) {
      const label = document.createElement("label");
      label.className = "poll-option";
      const input = document.createElement("input");
      input.type = "radio"; input.name = poll.id; input.value = option.id;
      input.required = true; input.disabled = Boolean(poll.vote);
      input.checked = poll.vote === option.id;
      const name = document.createElement("span"); name.textContent = option.label;
      const count = document.createElement("span"); count.className = "poll-count";
      count.textContent = `${option.votes} ${option.votes === 1 ? "vote" : "votes"}`;
      label.append(input, name, count); fieldset.append(label);
    }
    const button = document.createElement("button");
    button.className = "button poll-submit"; button.type = "submit";
    button.textContent = poll.vote ? "Vote recorded ✓" : "Cast your vote";
    button.disabled = Boolean(poll.vote);
    const total = document.createElement("p"); total.className = "poll-total";
    total.textContent = `${poll.total} ${poll.total === 1 ? "vote" : "votes"} so far`;
    const message = document.createElement("p");
    message.className = "poll-message"; message.setAttribute("role", "status");
    form.append(fieldset, button, total, message);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const choice = new FormData(form).get(poll.id);
      if (!choice) return;
      button.disabled = true; message.textContent = "Recording your vote…";
      try {
        const response = await fetch(`/api/polls/${poll.id}/vote`, {
          method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({choice})
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "Please try again.");
        render(result); status.textContent = "Thanks for helping shape Visirupt. Your vote is recorded.";
      } catch (error) {
        button.disabled = false; message.textContent = `Could not record your vote. ${error.message}`;
      }
    });
    polls.append(form);
  }
}
if (polls && status) {
  fetch("/api/polls").then(async (response) => {
    if (!response.ok) throw new Error("Polls unavailable");
    render(await response.json()); status.textContent = "";
  }).catch(() => { status.textContent = "Polls are temporarily unavailable. Please try again later."; });
}
