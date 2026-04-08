# Bash Pitfalls Reference

## SC2086 — Unquoted variable (word splitting)

```bash
# BAD — breaks if $file contains spaces
cp $file $dest

# GOOD
cp "$file" "$dest"
```

## SC2046 — Unquoted command substitution

```bash
# BAD
for f in $(find . -name "*.sh"); do ...

# GOOD — handles spaces in filenames
while IFS= read -r -d '' f; do ...
done < <(find . -name "*.sh" -print0)
```

## SC2006 — Backtick command substitution

```bash
# BAD — old style, doesn't nest well
result=`command`

# GOOD
result=$(command)
```

## Pipe + set -e interaction

```bash
# BAD — 'set -e' won't catch grep failure in pipe
cat file | grep pattern | wc -l

# GOOD — pipefail catches it
set -o pipefail
cat file | grep pattern | wc -l

# OR use subshell with explicit check
grep pattern file || true   # intentional continue
```

## Arithmetic: don't use let or expr

```bash
# BAD
let count=count+1
count=$(expr $count + 1)

# GOOD
(( count++ ))
count=$(( count + 1 ))
```

## Comparing numbers vs strings

```bash
# String comparison (lexicographic)
[[ "$a" == "$b" ]]
[[ "$a" < "$b" ]]

# Numeric comparison
[[ "$a" -eq "$b" ]]
[[ "$a" -lt "$b" ]]
(( a == b ))
(( a < b ))
```

## [ vs [[

```bash
# [ is POSIX, fragile with empty vars
[ $var == "foo" ]   # breaks if $var is empty

# [[ is bash builtin, safer
[[ $var == "foo" ]]  # handles empty gracefully
[[ $var =~ ^[0-9]+$ ]]  # regex support
```

## Subshell variable scope

```bash
# BAD — variable set inside pipe subshell is lost
count=0
cat file | while read -r line; do
  (( count++ ))   # this count dies with the subshell
done
echo "$count"  # always 0

# GOOD — process substitution keeps same shell
count=0
while read -r line; do
  (( count++ ))
done < <(cat file)
echo "$count"  # correct
```

## Default values

```bash
# Use parameter expansion for defaults
name="${1:-default_value}"
port="${PORT:-8080}"

# Require a variable
: "${API_KEY:?'API_KEY must be set'}"
```

## Array handling

```bash
# BAD — string, not array
files="a.txt b.txt c.txt"
cp $files /dest   # breaks on spaces

# GOOD — real array
files=(a.txt "b file.txt" c.txt)
cp "${files[@]}" /dest
```

## Function return values

```bash
# Functions return exit codes (0-255), not strings
# To return a string, use stdout:
get_version() {
  echo "1.2.3"
}
version=$(get_version)

# To return status:
is_valid() {
  [[ "$1" =~ ^[0-9]+$ ]]
}
if is_valid "$input"; then ...
```

## Conditional exit code check

```bash
# This suppresses exit on failure with set -e:
if some_command; then
  echo "success"
fi

# But this WILL exit if set -e is active:
some_command
echo "success"

# Explicit check without aborting:
if ! some_command; then
  err "command failed"
  # handle error
fi
```
