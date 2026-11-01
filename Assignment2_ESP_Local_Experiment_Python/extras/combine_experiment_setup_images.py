
import tkinter as tk
from tkinter import filedialog
from PIL import Image
import matplotlib.pyplot as plt

root = tk.Tk()
root.withdraw()

titles = [
    "A. Sender — target presentation",
    "B. Sender — fixation",
    "C. Receiver — fixation",
    "D. Receiver — four-choice response"
]

images = []

for title in titles:
    file_path = filedialog.askopenfilename(
        title=f"Select image: {title}",
        filetypes=[("Image files", "*.png *.jpg *.jpeg *.bmp")]
    )

    if not file_path:
        raise SystemExit("Image selection cancelled.")

    images.append(Image.open(file_path).convert("RGB"))

# Fixed dimensions for every panel
panel_width = 1200
panel_height = 800

processed_images = []

for img in images:
    # Resize while preserving the original aspect ratio
    img.thumbnail((panel_width, panel_height), Image.Resampling.LANCZOS)

    # Create an identical-sized white canvas
    canvas = Image.new("RGB", (panel_width, panel_height), "white")

    # Center the original image
    x = (panel_width - img.width) // 2
    y = (panel_height - img.height) // 2

    canvas.paste(img, (x, y))

    processed_images.append(canvas)

# Create a uniform 2x2 layout
fig, axes = plt.subplots(2, 2, figsize=(16, 12))

for ax, img, title in zip(axes.flatten(), processed_images, titles):
    ax.imshow(img)
    ax.set_title(title, fontsize=16, fontweight="bold", loc="left", pad=12)
    ax.axis("off")

plt.subplots_adjust(
    left=0.04,
    right=0.98,
    top=0.95,
    bottom=0.04,
    wspace=0.05,
    hspace=0.15
)

# Save the final figure
output_path = filedialog.asksaveasfilename(
    title="Save combined figure",
    defaultextension=".png",
    filetypes=[
        ("PNG image", "*.png"),
        ("PDF file", "*.pdf")
    ]
)

if output_path:
    fig.savefig(
        output_path,
        dpi=300,
        bbox_inches="tight",
        facecolor="white"
    )

    print(f"Saved: {output_path}")

plt.show()
root.destroy()
