# Install as /etc/profile.d/ai-switch-help.sh: shows the ai-switch commands on interactive login.
case $- in *i*) ;; *) return ;; esac

state=$(curl -s --max-time 2 http://localhost:8099/status 2>/dev/null)
case $state in
  allowed) s=$'\e[32m● AI allowed\e[0m' ;;
  blocked) s=$'\e[31m● AI blocked\e[0m' ;;
  *)       s=$'\e[33m● AI status unknown\e[0m' ;;
esac

cat <<HELP

  AI kill switch  ${s}
  ─────────────────────────────────────────────────────
  ai-status                  show what is on/off per provider
  ai-on  [provider]          allow AI (all, or one provider)
  ai-off [provider]          block AI (all, or one provider)
  ai-whitelist <provider>    always allow (e.g. mistral)
  ai-unwhitelist <provider>  remove from always-allowed
  ai-update                  refresh domain lists (auto 04:15)
  ai-idle                    idle check (auto every 5 min)

  providers: claude cohere copilot deepseek gemini huggingface
             metaai mistral openai others perplexity xai
  Status page: http://localhost:8099/
  Run these without sudo.

HELP
unset state s
