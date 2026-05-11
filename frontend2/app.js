const dropZone = document.getElementById("dropZone");
const fileInput = document.getElementById("fileInput");
const previewImage = document.getElementById("previewImage");
const emptyState = document.getElementById("emptyState");
const operationButtons = document.querySelectorAll(".operation");
const copyCommandButton = document.getElementById("copyCommand");
const commandText = document.getElementById("commandText");

dropZone.addEventListener("click", () => {
  fileInput.click();
});

fileInput.addEventListener("change", (event) => {
  const file = event.target.files[0];
  showPreview(file);
});

dropZone.addEventListener("dragover", (event) => {
  event.preventDefault();
  dropZone.classList.add("dragover");
});

dropZone.addEventListener("dragleave", () => {
  dropZone.classList.remove("dragover");
});

dropZone.addEventListener("drop", (event) => {
  event.preventDefault();
  dropZone.classList.remove("dragover");

  const file = event.dataTransfer.files[0];
  showPreview(file);
});

operationButtons.forEach((button) => {
  button.addEventListener("click", () => {
    operationButtons.forEach((btn) => btn.classList.remove("active"));
    button.classList.add("active");

    const operation = button.dataset.operation;
    applyPreviewOperation(operation);
  });
});

copyCommandButton.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(commandText.innerText);
    copyCommandButton.innerText = "Copied!";
    setTimeout(() => {
      copyCommandButton.innerText = "Copy";
    }, 1500);
  } catch {
    copyCommandButton.innerText = "Copy failed";
  }
});

function showPreview(file) {
  if (!file || !file.type.startsWith("image/")) {
    alert("Please choose an image file.");
    return;
  }

  const imageUrl = URL.createObjectURL(file);
  previewImage.src = imageUrl;
  previewImage.classList.remove("hidden");
  emptyState.classList.add("hidden");

  applyPreviewOperation(getSelectedOperation());
}

function getSelectedOperation() {
  const selected = document.querySelector(".operation.active");
  return selected ? selected.dataset.operation : "original";
}

function applyPreviewOperation(operation) {
  if (!previewImage.src) return;

  previewImage.style.filter = "none";
  previewImage.style.transform = "none";

  if (operation === "flip") {
    previewImage.style.transform = "rotate(180deg)";
  }

  if (operation === "mirror") {
    previewImage.style.transform = "scaleX(-1)";
  }

  if (operation === "grayscale") {
    previewImage.style.filter = "grayscale(100%)";
  }
}