# User Management System in Bash (Linux)

This project is a simple user management system written in **Bash scripting** for Linux. It was created as part of the **Operating Systems** course in the **1st year, 2nd semester**, for the **Computer Science** specialization at **CSIE (Faculty of Cybernetics, Statistics and Economic Informatics)**.

## 📋 Features

- User registration with email validation and 2FA code confirmation.
- User data stored in a CSV file (`users.csv`).
- Secure login using password + 2FA code sent via email.
- Secure logout with password reconfirmation.
- Asynchronous user report generation based on their home directory.
- Display currently logged-in users.
- Each user has a dedicated home directory (`home_<username>`) and a unique `user_id`.

## 🛠️ Technologies Used

- **Bash shell scripting**
- **SHA256** for password hashing
- **sendmail** (simulated email delivery)
- Core Linux tools: `cut`, `grep`, `sed`, `find`, `du`, `shuf`, `ps`

## ▶️ How to Run

1. Ensure your system has `bash`, `sendmail`, `sha256sum`, and standard Linux utilities installed.
2. Give the script execute permissions and run it:

```bash
chmod +x script.sh
./script.sh
