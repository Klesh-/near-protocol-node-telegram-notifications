#!/bin/bash
source .env

function notify() {
  echo "Send notify $*"
  curl -s --get "https://api.telegram.org/bot$TG_API_KEY/sendMessage" \
    --data-urlencode "chat_id=$TG_CHAT_ID" \
    --data-urlencode "text=$*"
}

function check_online() {
  R=$(curl -s http://$NODE_RPC/status | jq .version)

  LAST=$(cat state.status)
  NOW="0"
  if [ -n "$R" ]; then
    NOW="1"
  fi

  if [ "$LAST" != "$NOW" ]; then
    if [ "$NOW" == "0" ]; then
      notify "🚨 Node status changed: OFFLINE"
    else
      notify "✅ Node status changed: ONLINE"
    fi
    echo "$NOW" > state.status
  fi
}

function check_validator_status() {
  VALIDATORS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}' -H 'Content-Type: application/json' $NODE_RPC)
  CURRENT_VALIDATOR=$(echo "$VALIDATORS" | jq -c ".result.current_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  NEXT_VALIDATORS=$(echo "$VALIDATORS" | jq -c ".result.next_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  CURRENT_PROPOSALS=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))")
  KICK_REASON=$(echo "$VALIDATORS" | jq -c ".result.prev_epoch_kickout[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)

  echo "$VALIDATORS | $CURRENT_VALIDATOR | $NEXT_VALIDATORS | $CURRENT_PROPOSALS | $KICK_REASON"

  LAST_POS=$(cat state.position)
  NOW_POS="Not listed"

  [ -n "$CURRENT_VALIDATOR" ] && [ -z "$NOW_POS" ] && NOW_POS="✅ Validator"
  [ -n "$NEXT_VALIDATORS" ] && [ -z "$NOW_POS" ] && NOW_POS="🚀 Joining"
  [ -n "$CURRENT_PROPOSALS" ] && [ -z "$NOW_POS" ] && NOW_POS="👍 Proposal"
  [ -n "$KICK_REASON" ] && NOW_POS="🚨 Kicked: $KICK_REASON"

  if [ "$LAST_POS" != "$NOW_POS" ]; then
    notify "ℹ️ Position changed: $NOW_POS"
    echo "$NOW_POS" > state.position
  fi

  LAST_STAKE=$(cat state.stake)
  NOW_STAKE=$(echo "$CURRENT_VALIDATOR" | jq -c ".stake")

  if [ "$LAST_STAKE" != "$NOW_STAKE" ]; then
    notify "💰 Stake changed: $NOW_STAKE"
    echo "$NOW_STAKE" > state.stake
  fi
}

check_online
check_validator_status
