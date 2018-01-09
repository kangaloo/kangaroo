make_ssh_key() {
    echo "make ssh-key"
    if [ -f "~/.ssh/id_rsa" ]; then
        cat ~/.ssh/id_rsa >> ~/.ssh/authorized_keys
    else
        ssh-keygen -q -P "" -f ~/.ssh/id_rsa && cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
        chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub
    fi
}

make_ssh_key
