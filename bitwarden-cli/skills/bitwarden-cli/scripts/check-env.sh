#!/usr/bin/env sh
status=0
for name in BW_SESSION BW_CLIENTID BW_CLIENTSECRET; do
  eval "value=\${$name:-}"
  if [ -n "$value" ]; then echo "$name=set"; else echo "$name=unset"; status=1; fi
done
exit $status
