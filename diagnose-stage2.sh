#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/DADIA-Transport" || exit 1

echo "================================"
echo "DADIA STAGE 2 DEFINITIVE TEST"
echo "================================"

npm run typecheck || exit 1
npm run build || exit 1

cat > .stage2-test.mjs <<'JS'
import * as mod from "./dist/app.js";

const app = mod.default ?? mod.app;

if (!app) {
  console.error("APP_EXPORT_NOT_FOUND");
  console.error(Object.keys(mod));
  process.exit(2);
}

const server = app.listen(3101, "127.0.0.1", async () => {
  console.log("TEST_SERVER: 3101");

  try {
    const response = await fetch("http://127.0.0.1:3101/health");
    const text = await response.text();

    console.log("HTTP_STATUS:", response.status);
    console.log("HEALTH:", text);

    server.close(() => {
      process.exit(
        response.status === 200 &&
        text.includes('"database":true') &&
        text.includes('"redis":true')
          ? 0
          : 1
      );
    });
  } catch (error) {
    console.error("REQUEST_ERROR:", error);
    server.close(() => process.exit(3));
  }
});
JS

echo
echo "TESTING CURRENT COMPILED APP ON PORT 3101..."
echo

node --env-file=.env .stage2-test.mjs
RESULT=$?

rm -f .stage2-test.mjs

echo
echo "================================"

if [ "$RESULT" -eq 0 ]; then
  echo "DADIA STAGE 2: PASS"
  echo "CURRENT APP HEALTH IS CORRECT."
  echo "PROBLEM WAS OLD PORT-3000 PROCESS."
else
  echo "DADIA STAGE 2: FAILED"
  echo
  echo "CURRENT APP ITSELF IS FAILING."
  echo "NO MORE CHANGES WERE MADE."
fi

echo "================================"

exit "$RESULT"
