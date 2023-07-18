# simply read line and send message to nostr1. the message might be or might not be censored.

cat | while read line; do
    noscl publish $line;
done
