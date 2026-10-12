"use strict";
// This controls a labeled concept illustration, not the native game or VR.
const angle = document.querySelector("#view-angle");
const output = document.querySelector("#view-value");
const scene = document.querySelector(".optical");
const reset = document.querySelector("#reset-view");
if (angle && output && scene && reset) {
  const update = () => {
    const value = Math.max(-25, Math.min(25, Number(angle.value)));
    scene.style.setProperty("--view-angle", `${value}deg`);
    output.textContent = `${value < 0 ? "−" : ""}${Math.abs(value)}°`;
  };
  angle.addEventListener("input", update);
  reset.addEventListener("click", () => { angle.value = "-17"; update(); });
  update();
}
