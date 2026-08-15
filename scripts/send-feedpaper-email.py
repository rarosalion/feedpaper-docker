#!/usr/bin/env python3
import os
import smtplib
import sys
from email.message import EmailMessage

if len(sys.argv) != 2:
    print(f'Usage: {sys.argv[0]} /path/to/feedpaper-YYYY-MM-DD.epub', file=sys.stderr)
    sys.exit(2)

attachment_path = sys.argv[1]

required_env = [
    'FEEDPAPER_EMAIL_TO',
    'FEEDPAPER_EMAIL_FROM',
    'FEEDPAPER_SMTP_HOST',
]
for key in required_env:
    if not os.environ.get(key):
        raise SystemExit(f'{key} must be set')

to_addr = os.environ['FEEDPAPER_EMAIL_TO']
from_addr = os.environ['FEEDPAPER_EMAIL_FROM']
subject = os.environ.get('FEEDPAPER_EMAIL_SUBJECT', 'feedpaper newspaper')

smtp_host = os.environ['FEEDPAPER_SMTP_HOST']
smtp_port = int(os.environ.get('FEEDPAPER_SMTP_PORT', '587'))
starttls = os.environ.get('FEEDPAPER_SMTP_STARTTLS', 'true').lower() == 'true'
username = os.environ.get('FEEDPAPER_SMTP_USERNAME')
password = os.environ.get('FEEDPAPER_SMTP_PASSWORD')

msg = EmailMessage()
msg['Subject'] = subject
msg['From'] = from_addr
msg['To'] = to_addr
msg.set_content('Attached is the latest feedpaper EPUB export.')

with open(attachment_path, 'rb') as fh:
    msg.add_attachment(
        fh.read(),
        maintype='application',
        subtype='epub',
        filename=os.path.basename(attachment_path),
    )

with smtplib.SMTP(smtp_host, smtp_port) as server:
    if starttls:
        server.starttls()
    if username and password:
        server.login(username, password)
    server.send_message(msg)

print(f'Sent {os.path.basename(attachment_path)} to {to_addr}')
