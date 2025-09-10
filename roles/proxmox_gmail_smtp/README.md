# Proxmox Gmail SMTP Role

This Ansible role configures Gmail SMTP relay for Proxmox VE nodes, enabling email notifications for cluster events, backups, and system alerts.

## Requirements

- Gmail account with 2FA enabled
- Gmail App Password (not your regular password)
- Proxmox VE cluster

## Gmail App Password Setup

1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Navigate to Security → 2-Step Verification → App passwords
3. Generate a new app password for "Mail"
4. Use this app password in the `gmail_smtp_password` variable

## Variables

### Required Variables
- `gmail_smtp_username`: Your Gmail address
- `gmail_smtp_password`: Gmail App Password (16-character code)

### Optional Variables
- `gmail_smtp_server`: SMTP server (default: smtp.gmail.com)
- `gmail_smtp_port`: SMTP port (default: 587)
- `gmail_smtp_from_address`: From address (default: same as username)
- `gmail_smtp_from_name`: Display name (default: "Proxmox Cluster")
- `proxmox_notification_test`: Send test email after setup (default: false)

## Configuration

### Environment Variables (Recommended)
Create `.envrc` file:
```bash
export GMAIL_SMTP_USERNAME="your-email@gmail.com"
export GMAIL_SMTP_PASSWORD="your-16-char-app-password"
export GMAIL_SMTP_TEST="false"
```

Then run `direnv allow` to load variables.

### Alternative: Direct Configuration
Add to your `group_vars/pve01`:
```yaml
gmail_smtp_username: "your-email@gmail.com"
gmail_smtp_password: "your-16-char-app-password"
gmail_smtp_from_name: "Proxmox Cluster Production"
proxmox_notification_test: true
```

## Security Notes

- Never commit Gmail credentials to version control
- `.envrc` is automatically ignored by git
- Use direnv for automatic environment loading
- App passwords are safer than regular passwords for automation

## Testing

After deployment, test email functionality:

```bash
# On Proxmox node
echo "Test email body" | mail -s "Test Subject" your-email@gmail.com
```

## What This Role Does

1. Installs required packages (postfix, libsasl2-modules, mailutils)
2. Configures Postfix as Gmail SMTP relay
3. Sets up SASL authentication
4. Configures generic mapping for outgoing mail
5. Optionally sends test email to verify setup

## Integration with Proxmox

After this role runs, Proxmox can send notifications via:
- Datacenter → Notifications → Add → SMTP
- Use localhost:25 as SMTP server (Postfix relay)
- Or configure Proxmox to use Gmail directly with these same credentials