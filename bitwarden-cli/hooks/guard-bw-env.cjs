const RULES = [
  [/BW_[A-Za-z0-9_]/, 'BW_ 系の環境変数をコマンドで参照することは禁止されています。bw は環境変数を自動で読むため、コマンドに名前を書く必要はありません'],
  [/\bprintenv\b/, '環境変数の一覧表示は禁止されています（BW_ 系の値が出力されるため）'],
  [/(^|[;&|(`]|\$\()\s*(env|set|export|declare|typeset|compgen)(\s+-[a-zA-Z]+)*\s*($|[;&|)`>])/, '環境変数の一覧表示は禁止されています（BW_ 系の値が出力されるため）'],
  [/\/proc\/[^\s]*\/environ/, 'プロセスの環境変数の読み取りは禁止されています'],
  [/\bbw\s+unlock\b(?![^;&|]*--check)/, 'bw unlock はセッションキーを出力するため禁止されています。BW_SESSION はユーザーが用意します（確認は bw unlock --check）'],
];

const check = (command, env) => {
  for (const [pattern, reason] of RULES) if (pattern.test(command)) return reason;
  if (/(^|[^\w.-])bw(\s|$)/.test(command) && !env.BW_SESSION) {
    return 'BW_SESSION が設定されていないため bw を実行しません。ユーザーに BW_SESSION を設定した環境での再実行を依頼してください';
  }
  return null;
};

module.exports = { check };

if (require.main === module) {
  let input = '';
  process.stdin.on('data', (c) => { input += c; });
  process.stdin.on('end', () => {
    let command = '';
    try { command = JSON.parse(input).tool_input?.command ?? ''; } catch { process.exit(0); }
    const reason = check(command, process.env);
    if (reason) {
      console.error(reason);
      process.exit(2);
    }
  });
}
