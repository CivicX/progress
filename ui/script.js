const mock = {
  title: "Actions",
  text: "Staring at titties",
  duration: 5000,
};

let isProgress = false;
const progress = 0;

const circleSize = 45;
const circumference = (circleSize - 4) * 2 * Math.PI;

/*
    <h1>Actions</h1>
    <div id="circle">
        <svg>
            <circle cx="45" cy="45" r="41"></circle>
        </svg>
        <h1 id="progress-text">50</h1>
    </div>
    <h1>Staring at titties</h1>
*/

/*
window.addEventListener("keydown", (e) => {
    if (e.key !== " " || isProgress) return;
    isProgress = true;

    const progressWrapper = document.createElement("div");
    progressWrapper.id = "progress-wrapper";

    const title = document.createElement("h1");
    title.textContent = mock.title;

    const circleWrapper = document.createElement("div");
    circleWrapper.id = "circle";

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");

    const circle = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "circle"
    );

    circle.setAttribute("cx", circleSize);
    circle.setAttribute("cy", circleSize);
    circle.setAttribute("r", circleSize - 4);

    const shadowCircle = circle.cloneNode();
    shadowCircle.id = "shadow-circle";

    svg.append(shadowCircle, circle);

    const circleText = document.createElement("h1");
    circleText.id = "progress-text";
    circleText.textContent = "100";

    circleWrapper.append(svg, circleText);

    const text = document.createElement("h1");
    text.textContent = mock.text;

    progressWrapper.append(title, circleWrapper, text);
    wrapper.append(progressWrapper);

    let progress = 0;
    const interval = setInterval(() => {
        circle.style.strokeDashoffset =
            circumference - (progress / 100) * circumference;

        progress += 1000 / mock.duration;

        circleText.textContent = Math.floor(progress);

        if (progress >= 100) return clearInterval(interval);
    }, 10);

    setTimeout(() => {
        progressWrapper.className = "exit";
        console.log("EXIT");

        setTimeout(() => {
            wrapper.removeChild(progressWrapper);

            isProgress = false;
        }, 300);
    }, mock.duration + 75);
});
*/

window.addEventListener("message", ({ data }) => {
  switch (data.action) {
    case "start": {
      const wrapper = document.getElementById("wrapper");
      isProgress = true;

      const progressWrapper = document.createElement("div");
      progressWrapper.id = "progress-wrapper";

      const title = document.createElement("h1");
      title.textContent = data.title;

      const circleWrapper = document.createElement("div");
      circleWrapper.id = "circle";

      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");

      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");

      circle.setAttribute("cx", circleSize);
      circle.setAttribute("cy", circleSize);
      circle.setAttribute("r", circleSize - 4);

      const shadowCircle = circle.cloneNode();
      shadowCircle.id = "shadow-circle";

      svg.append(shadowCircle, circle);

      const circleText = document.createElement("h1");
      circleText.id = "progress-text";
      circleText.textContent = "100";

      circleWrapper.append(svg, circleText);

      const text = document.createElement("h1");
      text.textContent = data.text;

      progressWrapper.append(title, circleWrapper, text);
      wrapper.append(progressWrapper);

      let progress = 0;
      const interval = setInterval(() => {
        if (progressWrapper.className.includes("exit")) return clearInterval(interval);

        circle.style.strokeDashoffset = circumference - (progress / 100) * circumference;

        const newProgress = progress + 1000 / data.duration;

        if (Math.floor(newProgress) != Math.floor(progress)) {
          // console.log("changed");
          circleText.textContent = Math.floor(newProgress);

          if (data.onProgress) {
            fetch("https://progress/progress", {
              method: "POST",
              body: JSON.stringify({
                percentage: Math.floor(newProgress),
              }),
            });
          }
        }
        progress = newProgress;

        if (progress >= 100) return clearInterval(interval);
      }, 10);

      setTimeout(() => {
        progressWrapper.className = "exit";
        // console.log("EXIT");

        setTimeout(() => {
          wrapper.removeChild(progressWrapper);

          isProgress = false;

          fetch("https://progress/finished", { method: "POST" });
        }, 300);
      }, data.duration + 75);

      break;
    }

    case "stop": {
      const progressWrapper = document.getElementById("progress-wrapper");

      if (!progressWrapper) return;

      progressWrapper.className = "exit";

      setTimeout(() => {
        document.getElementById("wrapper").removeChild(progressWrapper);

        isProgress = false;
      }, 300);

      break;
    }

    default:
      break;
  }
});
