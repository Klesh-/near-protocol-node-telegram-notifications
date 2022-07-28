
# near-protocol-node-telegram-notifications
A Script to receive notifications in telegram about changes in state of NEAR Protocol staking node

# Setup

### Copy .env.example to .env
```sh
cp .env.example .env
```

### Fill script parameters in .env file
- **TG_API_KEY** - tegeram bot token which you got from @BotFather
- **TG_CHAT_ID** - telegram user id which you got from @getmyid_bot
- **POOL_ID** - your {PoolName}.factory.shardnet.near
- **NODE_RPC** - your node rpc url

### Add cron job
```sh
crontab -e
Paste:
* * * * * cd /path/to/script && ./report_node_status.sh &> /dev/null
```

# Stake Wars: Episode III. Challenge 004
https://github.com/near/stakewars-iii/blob/main/challenges/004.md

