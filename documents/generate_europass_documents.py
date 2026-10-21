#!/usr/bin/env python3
"""Generate a one-page Europass-style CV and cover letter as PDF files.

The project environment does not include a PDF rendering library, so this
script writes a compact, valid PDF directly using standard PDF drawing
operators and built-in fonts.
"""

from __future__ import annotations

from pathlib import Path
from textwrap import wrap


PAGE_WIDTH = 595
PAGE_HEIGHT = 842
OUTPUT_DIR = Path(__file__).resolve().parent


def pdf_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def text_width(text: str, size: float) -> float:
    widths = {
        " ": 0.28,
        ".": 0.25,
        ",": 0.25,
        ":": 0.28,
        ";": 0.28,
        "-": 0.33,
        "/": 0.33,
        "|": 0.2,
        "@": 0.85,
        "&": 0.7,
    }
    total = 0.0
    for char in text:
        if char in widths:
            total += widths[char]
        elif char.isupper():
            total += 0.64
        elif char.isdigit():
            total += 0.52
        else:
            total += 0.5
    return total * size


def wrap_text(text: str, max_width: float, size: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if current and text_width(candidate, size) > max_width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


class Canvas:
    def __init__(self) -> None:
        self.commands: list[str] = []

    def rect(self, x: float, y: float, w: float, h: float, color: tuple[float, float, float]) -> None:
        r, g, b = color
        self.commands.append(f"q {r:.3f} {g:.3f} {b:.3f} rg {x:.2f} {y:.2f} {w:.2f} {h:.2f} re f Q")

    def line(
        self,
        x1: float,
        y1: float,
        x2: float,
        y2: float,
        color: tuple[float, float, float],
        width: float = 1,
    ) -> None:
        r, g, b = color
        self.commands.append(f"q {r:.3f} {g:.3f} {b:.3f} RG {width:.2f} w {x1:.2f} {y1:.2f} m {x2:.2f} {y2:.2f} l S Q")

    def text(
        self,
        x: float,
        y: float,
        value: str,
        size: float = 10,
        font: str = "F1",
        color: tuple[float, float, float] = (0, 0, 0),
    ) -> None:
        r, g, b = color
        self.commands.append(
            f"BT /{font} {size:.2f} Tf {r:.3f} {g:.3f} {b:.3f} rg 1 0 0 1 {x:.2f} {y:.2f} Tm ({pdf_escape(value)}) Tj ET"
        )

    def wrapped(
        self,
        x: float,
        y: float,
        value: str,
        width: float,
        size: float = 10,
        leading: float = 12,
        font: str = "F1",
        color: tuple[float, float, float] = (0, 0, 0),
    ) -> float:
        for line in wrap_text(value, width, size):
            self.text(x, y, line, size=size, font=font, color=color)
            y -= leading
        return y

    def bullet_list(
        self,
        x: float,
        y: float,
        items: list[str],
        width: float,
        size: float = 8.3,
        leading: float = 10,
        color: tuple[float, float, float] = (0, 0, 0),
    ) -> float:
        for item in items:
            lines = wrap_text(item, width - 10, size)
            if not lines:
                continue
            self.text(x, y, "-", size=size, font="F2", color=color)
            self.text(x + 9, y, lines[0], size=size, color=color)
            y -= leading
            for continuation in lines[1:]:
                self.text(x + 9, y, continuation, size=size, color=color)
                y -= leading
        return y

    def stream(self) -> str:
        return "\n".join(self.commands)


def build_pdf(pages: list[str], destination: Path) -> None:
    objects: list[bytes] = []

    def add_object(body: str | bytes) -> int:
        if isinstance(body, str):
            body = body.encode("latin-1")
        objects.append(body)
        return len(objects)

    catalog_id = add_object("<< /Type /Catalog /Pages 2 0 R >>")
    pages_id = add_object("placeholder")
    regular_font_id = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    bold_font_id = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

    page_ids: list[int] = []
    for page in pages:
        stream = page.encode("latin-1")
        content_id = add_object(b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n" + stream + b"\nendstream")
        page_id = add_object(
            f"<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
            f"/Resources << /Font << /F1 {regular_font_id} 0 R /F2 {bold_font_id} 0 R >> >> "
            f"/Contents {content_id} 0 R >>"
        )
        page_ids.append(page_id)

    objects[pages_id - 1] = f"<< /Type /Pages /Kids [{' '.join(f'{page_id} 0 R' for page_id in page_ids)}] /Count {len(page_ids)} >>".encode(
        "latin-1"
    )
    assert catalog_id == 1

    output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for index, body in enumerate(objects, start=1):
        offsets.append(len(output))
        output.extend(f"{index} 0 obj\n".encode("ascii"))
        output.extend(body)
        output.extend(b"\nendobj\n")

    xref_offset = len(output)
    output.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    output.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    output.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode("ascii")
    )
    destination.write_bytes(output)


def section_title(canvas: Canvas, x: float, y: float, text: str, width: float) -> float:
    blue = (0.05, 0.28, 0.49)
    canvas.text(x, y, text, size=9.2, font="F2", color=blue)
    canvas.line(x, y - 4, x + width, y - 4, color=(0.84, 0.88, 0.92), width=0.8)
    return y - 16


def sidebar_section(canvas: Canvas, x: float, y: float, title: str) -> float:
    canvas.text(x, y, title, size=8.4, font="F2", color=(1, 1, 1))
    canvas.line(x, y - 4, x + 120, y - 4, color=(0.95, 0.73, 0.16), width=1)
    return y - 15


def generate_cv() -> str:
    canvas = Canvas()
    blue = (0.05, 0.28, 0.49)
    dark = (0.12, 0.15, 0.18)
    light_text = (1, 1, 1)
    muted = (0.35, 0.40, 0.45)
    gold = (0.95, 0.73, 0.16)

    canvas.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, (1, 1, 1))
    canvas.rect(32, 36, 168, 770, blue)
    canvas.rect(32, 776, 168, 30, gold)
    canvas.text(47, 787, "EUROPASS", size=17, font="F2", color=blue)
    canvas.text(47, 762, "PERSONAL INFORMATION", size=8.2, font="F2", color=light_text)
    canvas.line(47, 758, 170, 758, color=gold, width=1)

    y = 742
    for line in [
        "Hafiz Qasim Ali",
        "Ajman, UAE",
        "h.qasimali007@gmail.com",
        "+971 50 289 6128",
    ]:
        canvas.text(47, y, line, size=8.0 if "@" not in line else 7.4, color=light_text)
        y -= 12

    y -= 8
    y = sidebar_section(canvas, 47, y, "JOB APPLIED FOR")
    canvas.wrapped(47, y, "Lead Flutter Developer / Senior Mobile Engineer", 125, size=8.0, leading=10, color=light_text)
    y -= 42

    y = sidebar_section(canvas, 47, y, "CORE SKILLS")
    y = canvas.bullet_list(
        47,
        y,
        [
            "Flutter architecture and state management",
            "Cross-platform mobile, web and desktop apps",
            "Technical leadership and mentoring",
            "RESTful API design and integration",
            "Performance optimization and scalability",
        ],
        128,
        size=7.3,
        leading=9,
        color=light_text,
    )

    y -= 8
    y = sidebar_section(canvas, 47, y, "TECHNOLOGIES")
    y = canvas.bullet_list(
        47,
        y,
        [
            "Flutter, Android SDK, Java, XML",
            "React Native, NativeScript, Angular, TypeScript",
            "Python backend services and business logic",
            "Firebase, SQLite, MongoDB",
            "Apple Pay, Stripe, push notifications, maps",
            "Git, Android Studio, third-party SDKs",
        ],
        128,
        size=7.1,
        leading=8.8,
        color=light_text,
    )

    y -= 8
    y = sidebar_section(canvas, 47, y, "LANGUAGES")
    for line in ["English", "Urdu", "Punjabi"]:
        canvas.text(47, y, line, size=7.8, color=light_text)
        y -= 11

    x = 222
    width = 330
    canvas.text(x, 790, "Curriculum Vitae", size=9, color=muted)
    canvas.text(x, 766, "Hafiz Qasim Ali", size=24, font="F2", color=blue)
    canvas.text(x, 749, "Lead Flutter Developer | Cross-platform Mobile Architect | Python API Development", size=8.3, color=dark)
    canvas.line(x, 738, x + width, 738, color=gold, width=2)

    y = 718
    y = section_title(canvas, x, y, "PROFILE", width)
    y = canvas.wrapped(
        x,
        y,
        "Lead Flutter Developer with 8+ years of software development experience in cross-platform mobile architecture, "
        "system design and team leadership. Builds scalable Flutter applications for Android, iOS, web and desktop, "
        "with hands-on Python backend and REST API delivery for e-commerce, POS, logistics and enterprise systems.",
        width,
        size=8.6,
        leading=10.4,
        color=dark,
    )

    y -= 8
    y = section_title(canvas, x, y, "WORK EXPERIENCE", width)

    def job(date: str, title: str, employer: str, bullets: list[str], y_pos: float) -> float:
        canvas.text(x, y_pos, date, size=7.6, font="F2", color=blue)
        canvas.text(x + 92, y_pos, title, size=8.9, font="F2", color=dark)
        y_pos -= 10.5
        canvas.text(x + 92, y_pos, employer, size=7.8, color=muted)
        y_pos -= 12
        return canvas.bullet_list(x + 92, y_pos, bullets, width - 92, size=7.6, leading=9.2, color=dark)

    y = job(
        "Oct 2021 - Present",
        "Lead / Senior Flutter Developer & Tech Lead",
        "IKLIX, Dubai",
        [
            "Led architecture and development of Flutter applications across mobile, web and desktop platforms.",
            "Owned e-commerce ecosystem modules including POS, delivery, dashboards and inventory systems.",
            "Developed Python backend services, RESTful APIs and business integrations.",
            "Integrated Apple Pay, Stripe, Odoo and third-party SDKs while improving release stability.",
            "Mentored developers through code reviews, best practices and performance improvements.",
        ],
        y,
    )
    y -= 8
    y = job(
        "Sep 2018 - Aug 2021",
        "Technical Developer",
        "Massar, Dubai",
        [
            "Developed iOS and Android applications with NativeScript and integrated native plugins.",
            "Published production applications to Play Store and App Store.",
        ],
        y,
    )
    y -= 8
    y = job(
        "Dec 2015 - Mar 2017",
        "Android Developer",
        "Al-Hafiz Design Center & Jolta Technology, Pakistan",
        [
            "Built native and hybrid Android applications, integrated REST APIs and improved production apps.",
            "Worked on Arduino-based home automation and connected mobile features.",
        ],
        y,
    )

    y -= 10
    y = section_title(canvas, x, y, "EDUCATION AND TRAINING", width)
    canvas.text(x, y, "2011 - 2015", size=7.6, font="F2", color=blue)
    canvas.text(x + 92, y, "Bachelor of Software Engineering", size=8.7, font="F2", color=dark)
    y -= 11
    canvas.text(x + 92, y, "GC University Faisalabad, Pakistan", size=7.8, color=muted)

    y -= 22
    y = section_title(canvas, x, y, "DIGITAL AND COMMUNICATION COMPETENCES", width)
    canvas.wrapped(
        x,
        y,
        "Strong collaborator with experience leading releases, mentoring engineers, reviewing code and translating product "
        "requirements into scalable mobile and backend solutions.",
        width,
        size=8.1,
        leading=9.8,
        color=dark,
    )

    canvas.text(438, 45, "One-page Europass-style CV", size=7, color=muted)
    return canvas.stream()


def generate_cover_letter() -> str:
    canvas = Canvas()
    blue = (0.05, 0.28, 0.49)
    gold = (0.95, 0.73, 0.16)
    dark = (0.12, 0.15, 0.18)
    muted = (0.35, 0.40, 0.45)

    canvas.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, (1, 1, 1))
    canvas.rect(0, 805, PAGE_WIDTH, 37, blue)
    canvas.rect(0, 798, PAGE_WIDTH, 7, gold)
    canvas.text(48, 777, "Hafiz Qasim Ali", size=23, font="F2", color=blue)
    canvas.text(48, 760, "Lead Flutter Developer", size=11, color=dark)
    canvas.text(48, 744, "Ajman, UAE | h.qasimali007@gmail.com | +971 50 289 6128", size=8.8, color=muted)

    y = 706
    canvas.text(48, y, "12 May 2026", size=9.5, color=dark)
    y -= 32
    canvas.text(48, y, "Hiring Manager", size=10, font="F2", color=dark)
    y -= 14
    canvas.text(48, y, "Re: Lead Flutter Developer / Senior Mobile Engineer", size=10, font="F2", color=blue)
    y -= 34
    canvas.text(48, y, "Dear Hiring Manager,", size=10.5, color=dark)
    y -= 25

    paragraphs = [
        "I am writing to express my interest in a Lead Flutter Developer or Senior Mobile Engineer role. With more than eight years of software development experience, I bring strong expertise in Flutter architecture, cross-platform mobile delivery and practical backend API development.",
        "In my current role with IKLIX in Dubai, I lead the architecture and development of Flutter applications across Android, iOS, web and desktop. I have owned product areas including e-commerce, POS, delivery, dashboards and inventory systems, while also developing Python backend services and RESTful APIs that support business integrations.",
        "My background includes payment and third-party SDK integrations such as Apple Pay, Stripe, Odoo, push notifications, maps and geolocation. I am comfortable mentoring developers, conducting code reviews and improving performance, scalability and release stability for production applications.",
        "I would welcome the opportunity to discuss how my mobile architecture, leadership and delivery experience can contribute to your engineering team. Thank you for your time and consideration.",
    ]
    for paragraph in paragraphs:
        y = canvas.wrapped(48, y, paragraph, 500, size=10.2, leading=14.2, color=dark)
        y -= 13

    y -= 8
    canvas.text(48, y, "Sincerely,", size=10.5, color=dark)
    y -= 19
    canvas.text(48, y, "Hafiz Qasim Ali", size=10.8, font="F2", color=dark)

    canvas.line(48, 82, 547, 82, color=(0.84, 0.88, 0.92), width=0.8)
    canvas.text(48, 65, "Cover Letter", size=7.6, color=muted)
    return canvas.stream()


def main() -> None:
    build_pdf([generate_cv()], OUTPUT_DIR / "Hafiz_Qasim_Ali_Europass_CV_One_Page.pdf")
    build_pdf([generate_cover_letter()], OUTPUT_DIR / "Hafiz_Qasim_Ali_Cover_Letter.pdf")


if __name__ == "__main__":
    main()
