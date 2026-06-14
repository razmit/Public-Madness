#!/usr/bin/env python3
import os
import sys
import smtplib
import requests
import anthropic
from email.mime.text import MIMEText

GENERUJ_URL = "https://api.e-konsulat.gov.pl/api/u-captcha/generuj"
SPRAWDZ_URL = "https://api.e-konsulat.gov.pl/api/u-captcha/sprawdz"
TERMINY_URL = "https://api.e-konsulat.gov.pl/api/rezerwacja-wizyt-wizowych/terminy/1180/1"
BOOKING_URL = "https://secure.e-konsulat.gov.pl/placowki/216/wiza-krajowa/wizyty/weryfikacja-obrazkowa"

NOTIFY_EMAIL = "rolin.azmitia.iii@gmail.com"


def make_session() -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "Content-Type": "application/json",
        "Origin": "https://secure.e-konsulat.gov.pl",
        "Referer": BOOKING_URL,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    })
    return s


def generate_captcha(session: requests.Session) -> dict:
    r = session.post(
        GENERUJ_URL,
        json={"imageWidth": 100, "imageHeight": 50},
        timeout=15,
    )
    r.raise_for_status()
    return r.json()  # {id, iloscZnakow, image}


def solve_captcha(image_b64: str, char_count: int) -> str:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=16,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/png",
                            "data": image_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": (
                            f"This CAPTCHA image contains exactly {char_count} alphanumeric characters. "
                            "Reply with only those characters, no spaces or punctuation."
                        ),
                    },
                ],
            }
        ],
    )
    return response.content[0].text.strip()


def verify_captcha(session: requests.Session, captcha_id: str, kod: str) -> tuple[bool, str]:
    r = session.post(
        SPRAWDZ_URL,
        json={"kod": kod, "token": captcha_id},
        timeout=15,
    )
    r.raise_for_status()
    data = r.json()
    return data.get("ok", False), data.get("token", "")


def check_appointments(session: requests.Session, captcha_token: str) -> dict:
    r = session.post(
        TERMINY_URL,
        json={"captchaToken": captcha_token},
        timeout=15,
    )
    r.raise_for_status()
    return r.json()


def send_email(subject: str, body: str) -> None:
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = NOTIFY_EMAIL
    msg["To"] = NOTIFY_EMAIL
    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
        smtp.login(NOTIFY_EMAIL, os.environ["GMAIL_APP_PASSWORD"])
        smtp.send_message(msg)


def main() -> None:
    session = make_session()
    captcha_token = None

    for attempt in range(1, 4):
        captcha = generate_captcha(session)
        kod = solve_captcha(captcha["image"], captcha["iloscZnakow"])
        print(f"Attempt {attempt}: CAPTCHA solved as '{kod}'")
        ok, captcha_token = verify_captcha(session, captcha["id"], kod)
        if ok:
            print("CAPTCHA accepted.")
            break
        print("CAPTCHA rejected, retrying...")
    else:
        print("ERROR: CAPTCHA failed after 3 attempts.", file=sys.stderr)
        sys.exit(1)

    result = check_appointments(session, captcha_token)
    dates = result.get("tabelaDni", [])
    queue = result.get("wolneMiejscaWKolejce", False)

    print(f"tabelaDni: {dates}")
    print(f"wolneMiejscaWKolejce: {queue}")

    if dates or queue:
        lines = [
            "Appointment slots have opened at the Polish Embassy in Panama!\n",
        ]
        if dates:
            lines.append(f"Available dates: {dates}\n")
        if queue:
            lines.append("Waiting list is open.\n")
        lines.append(f"\nBook now: {BOOKING_URL}\n")
        send_email(
            "Polish Embassy Panama — Appointment Available!",
            "\n".join(lines),
        )
        print("Notification email sent.")
    else:
        print("No appointments available.")


if __name__ == "__main__":
    main()
