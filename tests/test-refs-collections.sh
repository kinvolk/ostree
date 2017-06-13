#!/bin/bash
#
# Copyright © 2016 Red Hat, Inc.
# Copyright © 2017 Endless Mobile, Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

set -euo pipefail

. $(dirname $0)/libtest.sh

echo '1..2'

cd ${test_tmpdir}
mkdir repo
ostree_repo_init repo --collection-id cid

mkdir -p tree/root
touch tree/root/a

# Add a few commits
seq 5 | while read i; do
    echo a >> tree/root/a
    ${CMD_PREFIX} ostree --repo=repo commit --branch=test-$i -m test -s test tree
done

# The collection IDs should only be listed if --collections is passed.
${CMD_PREFIX} ostree --repo=repo refs | wc -l > refscount
assert_file_has_content refscount "^5$"

${CMD_PREFIX} ostree --repo=repo refs > refs
assert_file_has_content refs "^test\-1$"
assert_file_has_content refs "^test\-5$"
assert_not_file_has_content refs "cid"

${CMD_PREFIX} ostree --repo=repo refs --collections > refs
assert_file_has_content refs "^(cid, test-1)$"
assert_file_has_content refs "^(cid, test-5)$"

# Similarly, the collection IDs should only be listed when filtering if --collections is passed.
${CMD_PREFIX} ostree --repo=repo refs --list cid | wc -l > refscount
assert_file_has_content refscount "^0$"

${CMD_PREFIX} ostree --repo=repo refs --collections --list cid | wc -l > refscount
assert_file_has_content refscount "^5$"

# --delete by itself should fail.
${CMD_PREFIX} ostree --repo=repo refs --delete 2>/dev/null || true
${CMD_PREFIX} ostree --repo=repo refs | wc -l > refscount.delete1
assert_file_has_content refscount.delete1 "^5$"

# Deleting specific refs should work.
${CMD_PREFIX} ostree refs --delete 2>/dev/null && (echo 1>&2 "refs --delete (without prefix) unexpectedly succeeded!"; exit 1)
${CMD_PREFIX} ostree --repo=repo refs --delete test-1 test-2
${CMD_PREFIX} ostree --repo=repo refs | wc -l > refscount.delete2
assert_file_has_content refscount.delete2 "^3$"
${CMD_PREFIX} ostree --repo=repo refs > refs.delete2
assert_not_file_has_content refs.delete2 '^test-1$'
assert_not_file_has_content refs.delete2 '^test-2$'
assert_file_has_content refs.delete2 '^test-3$'

# Deleting by collection ID should only work if --collections is passed.
${CMD_PREFIX} ostree refs --repo=repo --delete cid
${CMD_PREFIX} ostree refs --repo=repo | wc -l > refscount.delete3
assert_file_has_content refscount.delete3 "^3$"

${CMD_PREFIX} ostree refs --repo=repo --collections --delete cid
${CMD_PREFIX} ostree refs --repo=repo | wc -l > refscount.delete4
assert_file_has_content refscount.delete4 "^0$"

# Add a few more commits, to test --create
${CMD_PREFIX} ostree --repo=repo commit --branch=ctest -m ctest -s ctest tree

${CMD_PREFIX} ostree --repo=repo refs | wc -l > refscount
assert_file_has_content refscount "^1$"

# and test mirrored branches
${CMD_PREFIX} ostree --repo=repo refs --collections --create=new-cid:ctest-mirror ctest

${CMD_PREFIX} ostree --repo=repo refs | wc -l > refscount
assert_file_has_content refscount "^1$"
${CMD_PREFIX} ostree --repo=repo refs --collections | wc -l > refscount
assert_file_has_content refscount "^2$"

${CMD_PREFIX} ostree --repo=repo refs > refs
assert_file_has_content refs "^ctest$"
assert_not_file_has_content refs "^ctest-mirror$"

${CMD_PREFIX} ostree --repo=repo refs --collections > refs
assert_file_has_content refs "^(cid, ctest)$"
assert_file_has_content refs "^(new-cid, ctest-mirror)$"

echo "ok 1 refs collections"

# Test that listing, creating and deleting refs works from an old repository
# where refs/mirrors doesn’t exist to begin with.
rm -rf repo/refs/mirrors
${CMD_PREFIX} ostree --repo=repo refs

rm -rf repo/refs/mirrors
${CMD_PREFIX} ostree --repo=repo refs --collections

rm -rf repo/refs/mirrors
${CMD_PREFIX} ostree --repo=repo refs --collections --create=new-cid:ctest-mirror ctest
${CMD_PREFIX} ostree --repo=repo refs --collections > refs
assert_file_has_content refs "^(cid, ctest)$"
assert_file_has_content refs "^(new-cid, ctest-mirror)$"

rm -rf repo/refs/mirrors
${CMD_PREFIX} ostree refs --repo=repo --collections --delete nonexistent

echo "ok 2 refs collections in old repository"
