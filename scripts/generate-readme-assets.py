#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "docs" / "assets" / "readme"
ICON_PATH = ASSET_DIR / "vesper-icon.png"

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_MONO = "/System/Library/Fonts/SFNSMono.ttf"
FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size: int, *, cn: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_CN if cn else FONT_MONO if mono else FONT_ROUNDED
    return ImageFont.truetype(path, size)


def gradient_background(width: int, height: int) -> Image.Image:
    img = Image.new("RGB", (width, height), "#f7f9ff")
    px = img.load()
    stops = [
        (0.12, 0.15, (214, 229, 255)),
        (0.40, 0.20, (248, 247, 255)),
        (0.78, 0.70, (255, 232, 181)),
        (0.93, 0.08, (233, 246, 224)),
        (0.05, 0.93, (238, 247, 255)),
    ]
    for y in range(height):
        for x in range(width):
            base = [248, 250, 255]
            for sx, sy, color in stops:
                dx = x / width - sx
                dy = y / height - sy
                weight = max(0, 1 - (dx * dx + dy * dy) ** 0.5 / 0.72) ** 2
                for i in range(3):
                    base[i] = int(base[i] * (1 - weight * 0.55) + color[i] * weight * 0.55)
            px[x, y] = tuple(base)
    return img.filter(ImageFilter.GaussianBlur(0.2))


def rounded(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(draw: ImageDraw.ImageDraw, xy, value: str, size: int, color: str, *, cn: bool = False, mono: bool = False, anchor=None):
    draw.text(xy, value, fill=color, font=font(size, cn=cn, mono=mono), anchor=anchor)


def wrap(draw: ImageDraw.ImageDraw, value: str, max_width: int, size: int, *, cn: bool = False) -> list[str]:
    f = font(size, cn=cn)
    units = list(value) if cn else value.split(" ")
    lines: list[str] = []
    current = ""
    for unit in units:
        candidate = current + unit if cn else (unit if not current else f"{current} {unit}")
        if draw.textlength(candidate, font=f) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = unit
    if current:
        lines.append(current)
    return lines


def multi_text(draw: ImageDraw.ImageDraw, x: int, y: int, value: str, max_width: int, size: int, color: str, *, cn: bool = False, line_gap: int = 8):
    for line in wrap(draw, value, max_width, size, cn=cn):
        text(draw, (x, y), line, size, color, cn=cn)
        y += size + line_gap
    return y


def paste_icon(canvas: Image.Image, xy: tuple[int, int], size: int):
    icon = Image.open(ICON_PATH).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    shell = Image.new("RGBA", (size + 16, size + 16), (255, 255, 255, 0))
    d = ImageDraw.Draw(shell)
    d.rounded_rectangle((0, 0, size + 16, size + 16), radius=30, fill=(255, 255, 255, 220))
    shell.alpha_composite(icon, (8, 8))
    canvas.alpha_composite(shell, xy)


def phone(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, cn: bool):
    rounded(draw, (x, y, x + w, y + h), 72, "#0b1226")
    rounded(draw, (x + 22, y + 22, x + w - 22, y + h - 22), 55, "#ffffff")
    rounded(draw, (x + w // 2 - 72, y + 45, x + w // 2 + 72, y + 75), 18, "#0b1226")

    top = y + 120
    text(draw, (x + 74, top), "对话" if cn else "Chat", 31, "#111827", cn=cn)

    user = "明天帮我安排学习和健身，记得留出吃饭时间" if cn else "Plan study and gym tomorrow, and keep meals open."
    assistant = "我会拆成独立事项，并保留午餐、晚餐和休息。" if cn else "I’ll split them into separate items and reserve meal breaks."

    rounded(draw, (x + 74, y + 185, x + w - 88, y + 270), 28, "#eef3fb")
    multi_text(draw, x + 104, y + 204, user, w - 230, 25 if cn else 23, "#1f2937", cn=cn, line_gap=5)

    rounded(draw, (x + 120, y + 308, x + w - 70, y + 390), 30, "#2f8cff")
    multi_text(draw, x + 150, y + 327, assistant, w - 230, 22 if cn else 20, "#ffffff", cn=cn, line_gap=4)

    cards = [
        ("深度学习", "08:30 - 11:30 · 通知") if cn else ("Deep work", "08:30 - 11:30 · notification"),
        ("午餐休息", "12:00 - 13:00 · 预留") if cn else ("Lunch buffer", "12:00 - 13:00 · reserved"),
        ("健身", "16:30 - 17:30 · 提醒") if cn else ("Gym", "16:30 - 17:30 · reminder"),
    ]
    cy = y + 390
    colors = ["#2f8cff", "#f59e0b", "#22c55e"]
    for idx, (title, detail) in enumerate(cards):
        rounded(draw, (x + 74, cy, x + w - 74, cy + 92), 25, "#f8fbff", "#cfe0ff", 2)
        rounded(draw, (x + 105, cy + 22, x + 153, cy + 70), 18, "#e7f0ff")
        draw.ellipse((x + 121, cy + 36, x + 137, cy + 52), fill=colors[idx])
        draw.line((x + 129, cy + 52, x + 129, cy + 73), fill="#b5caee", width=3)
        text(draw, (x + 178, cy + 19), title, 27 if cn else 25, "#111827", cn=cn)
        text(draw, (x + 178, cy + 55), detail, 22 if cn else 20, "#6b7a90", cn=cn)
        cy += 108


def side_card(draw: ImageDraw.ImageDraw, x: int, y: int, title: str, detail: str, color: str, *, cn: bool):
    rounded(draw, (x, y, x + 245, y + 150), 30, "#ffffff", None)
    text(draw, (x + 32, y + 32), title, 29 if cn else 28, "#111827", cn=cn)
    text(draw, (x + 32, y + 75), detail, 20 if cn else 19, "#65738a", cn=cn)
    draw.ellipse((x + 32, y + 108, x + 59, y + 135), fill=color)
    draw.line((x + 45, y + 135, x + 45, y + 146), fill="#b9ccec", width=3)


def chip(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, sub: str, *, cn: bool):
    rounded(draw, (x, y, x + 185, y + 70), 20, "#ffffffd8", "#d4e2f6", 1)
    text(draw, (x + 16, y + 15), label, 19 if cn else 18, "#1f2937", cn=cn)
    text(draw, (x + 16, y + 42), sub, 15 if cn else 14, "#718096", cn=cn, mono=not cn)


def build(locale: str):
    cn = locale == "zh"
    W, H = 1600, 900
    base = gradient_background(W, H).convert("RGBA")
    draw = ImageDraw.Draw(base)

    paste_icon(base, (94, 88), 96)
    rounded(draw, (252, 112, 430, 158), 23, "#ffffffd8")
    text(draw, (282, 122), "开发预览" if cn else "DEV PREVIEW", 24, "#2f8cff", cn=cn)

    if cn:
        title_lines = ["Vesper", "把一句话变成", "可确认的生活行动"]
        lead = "原生 iPhone AI 私人助理：对话输入、卡片确认、本机执行。"
        sub = "提醒、闹钟、日历、日记与健康上下文，全都先给你看清楚再执行。"
        primary, secondary = "下载 IPA", "阅读说明"
        chips = [("多模型", "OpenAI / DeepSeek"), ("原生执行", "闹钟 + 日历"), ("本地优先", "SwiftData + Keychain")]
    else:
        title_lines = ["Vesper", "Turn one sentence", "into confirmed life actions"]
        lead = "A native iPhone AI companion for reminders, alarms, calendar planning, diary workflows, and weekly reviews."
        sub = "Natural language becomes editable cards before anything touches your system."
        primary, secondary = "Download IPA", "Read the docs"
        chips = [("Providers", "OpenAI / DeepSeek"), ("Native outputs", "AlarmKit + EventKit"), ("Local-first", "SwiftData + Keychain")]

    y = 250
    for idx, line in enumerate(title_lines):
        text(draw, (102, y), line, 62 if idx == 0 else 46, "#101827", cn=cn)
        y += 66 if idx == 0 else 54

    y += 24
    y = multi_text(draw, 104, y, lead, 560, 27 if cn else 25, "#4b5870", cn=cn, line_gap=8)
    y = multi_text(draw, 104, y + 16, sub, 560, 24 if cn else 22, "#5c6880", cn=cn, line_gap=7)

    rounded(draw, (104, 640, 354, 704), 31, "#2f8cff")
    text(draw, (229, 657), primary, 21 if cn else 20, "#ffffff", cn=cn, anchor="ma")
    rounded(draw, (376, 640, 602, 704), 31, "#ffffffc8", "#c9d8ef", 1)
    text(draw, (489, 657), secondary, 21 if cn else 20, "#1f2937", cn=cn, anchor="ma")

    cx = 104
    for label, sublabel in chips:
        chip(draw, cx, 760, label, sublabel, cn=cn)
        cx += 205

    phone(draw, 720, 88, 500, 730, cn)

    if cn:
        side = [
            ("时间线", "日历式日视图", "#2f8cff"),
            ("日记周记", "早晚主动对话", "#f59e0b"),
            ("健康上下文", "睡眠与运动建议", "#22c55e"),
        ]
    else:
        side = [
            ("Timeline", "calendar-like day view", "#2f8cff"),
            ("Journal", "morning / evening prompts", "#f59e0b"),
            ("Health", "sleep and activity context", "#22c55e"),
        ]
    sy = 138
    for item in side:
        side_card(draw, 1284, sy, item[0], item[1], item[2], cn=cn)
        sy += 228

    out = ASSET_DIR / f"vesper-hero-{locale}.png"
    base.convert("RGB").save(out, "PNG", optimize=True)
    print(out)


def main():
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for locale in ("zh", "en"):
        build(locale)


if __name__ == "__main__":
    main()
