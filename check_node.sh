#!/bin/bash

TG_TOKEN="<tg_bot_token>
TG_CHAT_ID="<tg_chat_id>"
POOL_ID="<pool_name>"
NODE_RPC="127.0.0.1:3030"

function notify() {
  echo "Send notify $*"
  curl -s --get "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
    --data-urlencode "chat_id=$TG_CHAT_ID" \
    --data-urlencode "text=$*"
}

function check_online() {
  R=$(curl -s http://$NODE_RPC/status | jq .version)

  LAST=$(cat node.status)
  NOW="0"
  if [ -n "$R" ]; then
    NOW="1"
  fi

  if [ "$LAST" != "$NOW" ]; then
    if [ "$NOW" == "0" ]; then
      notify "🚨 Node status changed: <b>OFFLINE</b>"
    else
      notify "✅ Node status changed: <b>ONLINE</b>"
    fi
    echo "$NOW" > node.status
  fi
}

function check_validator_status() {
  VALIDATORS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}' -H 'Content-Type: application/json' $NODE_RPC)
  CURRENT_VALIDATOR=$(echo "$VALIDATORS" | jq -c ".result.current_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  NEXT_VALIDATORS=$(echo "$VALIDATORS" | jq -c ".result.next_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  CURRENT_PROPOSALS=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))")
  KICK_REASON=$(echo "$VALIDATORS" | jq -c ".result.prev_epoch_kickout[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)

  echo "$VALIDATORS | $CURRENT_VALIDATOR | $NEXT_VALIDATORS | $CURRENT_PROPOSALS | $KICK_REASON"

  LAST_POS=$(cat node.position)
  NOW_POS=""

  [ -n "$CURRENT_VALIDATOR" ] && [ -z "$NOW_POS" ] && NOW_POS="✅ Validator"
  [ -n "$NEXT_VALIDATORS" ] && [ -z "$NOW_POS" ] && NOW_POS="🚀 Joining"
  [ -n "$CURRENT_PROPOSALS" ] && [ -z "$NOW_POS" ] && NOW_POS="👍 Proposal"
  [ -n "$KICK_REASON" ] && NOW_POS="🚨 Kicked: $KICK_REASON"

  if [ "$LAST_POS" != "$NOW_POS" ]; then
    notify "ℹ️ Position changed: $NOW_POS"
    echo "$NOW_POS" > node.position
  fi

  LAST_STAKE=$(cat node.stake)
  NOW_STAKE=$(echo "$CURRENT_VALIDATOR" | jq -c ".stake")

  if [ "$LAST_STAKE" != "$NOW_STAKE" ]; then
    notify "💰 Stake changed: $NOW_STAKE"
    echo "$NOW_STAKE" > node.stake
  fi

  LAST_BLOCK=$(cat node.blocks)
  NOW_BLOCK=$(echo "$CURRENT_VALIDATOR" | jq -c ".num_produced_blocks")

  if [ "$LAST_BLOCK" != "$NOW_BLOCK" ]; then
    notify "Produced blocks changed: $NOW_BLOCK"
    echo "$NOW_BLOCK" > node.blocks
  fi

  LAST_CHUNKS=$(cat node.chunks)
  NOW_CHUNKS=$(echo "$CURRENT_VALIDATOR" | jq -c ".num_produced_chunks")

  if [ "$LAST_CHUNKS" != "$NOW_CHUNKS" ]; then
    notify "Produced chunks changed: $NOW_CHUNKS"
    echo "$NOW_CHUNKS" > node.chunks
  fi
}

function check_peers() {
  NOW_PEERS=$(journalctl -n 10 -u neard | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | sed -nE "s/^.*\s([0-9]+.peers).*$/\1/p" | tail -n 1)
  LAST_PEERS=$(cat node.peers)
  if [ "$LAST_PEERS" != "$NOW_PEERS" ]; then
    notify "📶 Peers changed: $NOW_PEERS"
    echo "$NOW_PEERS" > node.peers
  fi
}

check_online
check_validator_status
check_peers
