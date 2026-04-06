module.exports = {
    extends: ['@commitlint/config-conventional'],
    rules: {
        'type-enum': [2, 'always', ['feat', 'fix', 'docs', 'chore', 'ci', 'refactor', 'perf', 'style', 'revert']],
        'subject-empty': [2, 'never'],
        'type-empty': [2, 'never'],
    },
};
