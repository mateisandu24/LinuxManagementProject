#!/bin/bash

USERS_FILE="users.csv"
LOGGED_USERS_FILE="logged_in_users.txt"

declare -a logged_in_users

init_files() {
    if [ ! -f "$USERS_FILE" ]; then 
        echo "username,email,password_hash,home_dir,user_id,last_login" > "$USERS_FILE"
    fi
    if [ ! -f "$LOGGED_USERS_FILE" ]; then
        touch "$LOGGED_USERS_FILE"
    fi
    if [ -s "$LOGGED_USERS_FILE" ]; then
        while read -r user; do
            logged_in_users+=("$user")
        done < "$LOGGED_USERS_FILE"
    fi
}

user_exists() {
    local username="$1"
    cut -d',' -f1 "$USERS_FILE" | grep -q "^$username$" 2>/dev/null
}

email_exists() {
    local email="$1"
    cut -d',' -f2 "$USERS_FILE" | grep -q "^$email$" 2>/dev/null
}

validate_email() {
    local email="$1"
    [[ $email =~ ^[A-Za-z0-9._-]{3,}@[A-Za-z0-9.-]{2,}\.[A-Za-z]{2,}$ ]]
}

get_user_password_hash() {
    local username="$1"
    grep "^$username," "$USERS_FILE" | cut -d',' -f3
}

is_user_logged() {
    local username="$1"
    grep -q "^$username$" "$LOGGED_USERS_FILE" 2>/dev/null
}

add_to_logged_users() {
    local username="$1"
    if ! is_user_logged "$username"; then
        echo "$username" >> "$LOGGED_USERS_FILE"
        logged_in_users+=("$username")
    fi
}

remove_from_logged_users() {
    local username="$1"
    if is_user_logged "$username"; then
        local temp_array=()
        for user in "${logged_in_users[@]}"; do
            [ "$user" != "$username" ] && temp_array+=("$user")
        done
        > "$LOGGED_USERS_FILE"
        for user in "${temp_array[@]}"; do
            echo "$user" >> "$LOGGED_USERS_FILE"
        done
        logged_in_users=("${temp_array[@]}")
        return 0
    else
        return 1
    fi
}

show_logged_users() {
    if [ ! -s "$LOGGED_USERS_FILE" ]; then
        echo "Nu exista utilizatori logati."
        return
    fi

    echo "Utilizatori logati:"
    while read -r user; do
        info=$(grep "^$user," "$USERS_FILE")
        if [ -n "$info" ]; then
            email=$(echo "$info" | cut -d',' -f2)
            home=$(echo "$info" | cut -d',' -f4)
            last_login=$(echo "$info" | cut -d',' -f6)
            echo "- $user | $email | $home | last_login: $last_login"
        fi
    done < "$LOGGED_USERS_FILE"
}

get_user_home() {
    local username="$1"
    grep "^$username," "$USERS_FILE" | cut -d',' -f4
}

update_last_login() {
    local username="$1"
    local current_date=$(date "+%Y-%m-%d %H:%M:%S")
    sed -i "/^$username,/s/,[^,]*$/,$current_date/" "$USERS_FILE"
}

generate_user_id() {
    while :; do
        id=$(shuf -i 1000-99999 -n 1)
        ! cut -d',' -f5 "$USERS_FILE" | grep -q "^$id$" && echo "$id" && return
    done
}

send_email() {
    local recipient="$1"
    local subject="$2"
    local body="$3"

    {
        echo "To: $recipient"
        echo "Subject: $subject"
        echo ""
        echo "$body"
    } | /usr/sbin/sendmail -t 2>/dev/null
}

register_user() {
    echo "INREGISTRARE UTILIZATOR"
    echo "========================"

    while true; do
        read -p "Username: " username
        [ -z "$username" ] && echo "Eroare: Username gol" && continue
        [[ "$username" =~ [^a-zA-Z0-9_] ]] && echo "Eroare: Doar litere, cifre si _" && continue
        user_exists "$username" && echo "Eroare: Exista deja" && continue
        break
    done

    while true; do
        read -p "Email: " email
        [ -z "$email" ] && echo "Eroare: Email gol" && continue
        ! validate_email "$email" && echo "Eroare: Email invalid" && continue
        email_exists "$email" && echo "Eroare: Email deja folosit" && continue
        break
    done

    code=$(shuf -i 1000-9999 -n 1)
    send_email "$email" "Cod de confirmare pentru email" $'Salutare,\nCodul tau de inregistrare este: '"$code"$'\n\nEchipa ProjectApollo'

    read -p "Introdu codul primit pe email: " input_code
    [ "$input_code" != "$code" ] && echo "Cod 2FA incorect!" && return

    while true; do
        read -s -p "Parola: " password1; echo
        read -s -p "Confirma parola: " password2; echo
        [ "$password1" != "$password2" ] && echo "Parolele nu coincid!" && continue
        [ ${#password1} -lt 6 ] && echo "Minim 6 caractere!" && continue
        break
    done

    password_hash=$(echo -n "$password1" | sha256sum | cut -d' ' -f1)
    user_id=$(generate_user_id)
    home_dir="home_${username}"
    mkdir -p "$home_dir" 2>/dev/null
    last_login=$(date "+%Y-%m-%d %H:%M:%S")

    echo "$username,$email,$password_hash,$home_dir,$user_id,$last_login" >> "$USERS_FILE" 2>/dev/null
    add_to_logged_users "$username"

    send_email "$email" "Bun venit, $username!" $'Contul tau a fost creat si esti logat automat.\n\nEchipa ProjectApollo'

    echo "Contul a fost creat si esti logat automat, $username!"
}

login_user() {
    echo "AUTENTIFICARE"
    echo "============="
    read -p "Username: " username
    [ -z "$username" ] && echo "Eroare: Username gol" && return
    ! user_exists "$username" && echo "Eroare: Utilizator inexistent" && return
    is_user_logged "$username" && echo "Esti deja logat!" && return

    read -s -p "Parola: " password; echo
    [ -z "$password" ] && echo "Eroare: Parola goala" && return

    input_hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
    stored_hash=$(get_user_password_hash "$username")
    [ "$input_hash" != "$stored_hash" ] && echo "Parola incorecta!" && return

    email=$(grep "^$username," "$USERS_FILE" | cut -d',' -f2)
    code=$(shuf -i 1000-9999 -n 1)

    send_email "$email" "Cod 2FA Login" "Codul tau pentru login este: $code"

    read -p "Introdu codul primit pe email: " input_code
    [ "$input_code" != "$code" ] && echo "Cod 2FA incorect!" && return

    update_last_login "$username"
    add_to_logged_users "$username"
    home_dir=$(get_user_home "$username")
    mkdir -p "$home_dir"

    send_email "$email" "Confirmare login" "Salut $username! Te-ai autentificat cu succes la $(date '+%Y-%m-%d %H:%M').Echipa ProjectApollo."

    echo "Bun venit, $username!"
}

logout_user() {
    echo "LOGOUT UTILIZATOR"
    echo "================="
    echo

    # Afișează utilizatorii logați
    show_logged_users
    echo

    # Verifică dacă există utilizatori logați
    if [ ${#logged_in_users[@]} -eq 0 ]; then
        echo "Nu exista utilizatori logati."
        return 1
    fi

    read -p "Username pentru logout: " username

    if [ -z "$username" ]; then
        echo "Eroare: Username-ul nu poate fi gol!"
        return 1
    fi

    if ! user_exists "$username"; then
        echo "Eroare: Utilizatorul '$username' nu exista!"
        return 1
    fi

    if ! is_user_logged "$username"; then
        echo "Eroare: Utilizatorul '$username' nu este logat!"
        return 1
    fi

    read -s -p "Introdu parola pentru confirmare logout: " password; echo
    [ -z "$password" ] && echo "Parola goala!" && return 1

    input_hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
    stored_hash=$(get_user_password_hash "$username")

    if [ "$input_hash" != "$stored_hash" ]; then
        echo "Parola incorecta. Logout anulat."
        return 1
    fi

    # Elimină utilizatorul din array-ul logged_in_users
    if remove_from_logged_users "$username"; then
        echo "Logout reusit pentru '$username'!"
        echo "Data logout: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        show_logged_users
    else
        echo "Eroare la logout!"
        return 1
    fi
}

generate_report_async() {
    local username="$1"
    local home_dir="$2"
    local report_file="$3"

    sleep 2

    local num_files=$(find "$home_dir" -type f 2>/dev/null | wc -l)
    local num_dirs=$(find "$home_dir" -type d 2>/dev/null | wc -l)
    local total_size=$(du -sh "$home_dir" 2>/dev/null | cut -f1)

    cat > "$report_file" << EOF
RAPORT UTILIZATOR: $username
Generat: $(date '+%Y-%m-%d %H:%M:%S')
Director: $home_dir

STATISTICI:
- Fisiere: $num_files
- Directoare: $num_dirs
- Dimensiune totala: $total_size

DETALII:
EOF

    if [ $num_files -le 10 ]; then
        echo "Lista fisiere:" >> "$report_file"
        find "$home_dir" -type f -printf "  %f (%s bytes)\n" 2>/dev/null >> "$report_file"
    else
        echo "Primele 10 fisiere:" >> "$report_file"
        find "$home_dir" -type f -printf "  %f (%s bytes)\n" 2>/dev/null | head -10 >> "$report_file"
        echo "  ... si inca $((num_files - 10)) fisiere" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "Raport generat cu succes!" >> "$report_file"

    echo "[$(date '+%H:%M:%S')] Raportul pentru '$username' a fost finalizat!"
    echo
    echo "RAPORT PENTRU $username"
    cat "$report_file"
    
}

generate_user_report() {
    echo "GENERARE RAPORT UTILIZATOR"
    echo "=========================="
    echo

    read -p "Username pentru raport: " username

    if [ -z "$username" ]; then
        echo "Eroare: Username-ul nu poate fi gol!"
        return 1
    fi

    if ! user_exists "$username"; then
        echo "Eroare: Utilizatorul '$username' nu exista!"
        return 1
    fi

    home_dir=$(grep "^$username," "$USERS_FILE" | cut -d',' -f4)

    if [ ! -d "$home_dir" ]; then
        echo "Directorul home nu exista. Il creez..."
        mkdir -p "$home_dir"
    fi

    report_file="$home_dir/raport_utilizator.txt"
    echo "Generez raportul pentru '$username'..."
    echo "Director: $home_dir"
    echo "Fisier raport: $report_file"
    echo
    echo "Raportul se genereaza asincron..."

    generate_report_async "$username" "$home_dir" "$report_file" &
    local report_pid=$!
    echo "Raport in procesare (PID: $report_pid)"
    echo "Verificare cu: ps $report_pid"
}

main_menu() {
    echo "SISTEM MANAGEMENT UTILIZATORI"
    echo "============================="
    echo
    
    while true; do
        echo "MENIU:"
        echo "1. Inregistrare utilizator"
        echo "2. Autentificare"  
        echo "3. Logout"
        echo "4. Generare raport"
        echo "5. Vezi utilizatori logati"
        echo "6. Iesire"
        echo
        
        read -p "Optiune (1-6): " optiune
        echo
        
        case $optiune in
            1) register_user ;;
            2) login_user ;;
            3) logout_user ;;
            4) generate_user_report ;;
            5) show_logged_users ;;
            6) echo "La revedere!" && exit 0 ;;
            *) echo "Optiune invalida!" ;;
        esac
        
        echo "----------------------------"
        read -p "ENTER pentru continuare..."
        echo
    done
}

# PUNCTUL DE INTRARE
init_files

echo "SISTEM MANAGEMENT UTILIZATORI"
echo "Initializat cu succes!"
echo "Fisier utilizatori: $USERS_FILE"
echo

main_menu
