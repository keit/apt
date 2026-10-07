#!/bin/bash
# Builds the APT repository into an output directory (default: public/)
# from the latest published GitHub release of every repo in apps.txt, and
# signs it with the key already imported into gpg. Run by the publish
# workflow; needs gh (authenticated), apt-ftparchive (apt-utils), gpg.
#
#   ./build-repo.sh [out-dir]
#
# Built from scratch each time: nothing but this script, apps.txt and
# site/ lives in git, and only each app's latest release is published.
set -euo pipefail

key=2F139F75C569FA771904732EE5944DBBD89DD18E
suite=stable
archs=(amd64 arm64)
out=${1:-public}

cd "$(dirname "$0")"
rm -rf "${out:?}"
mkdir -p "$out"
cp -r site/. "$out/"
cp keit.gpg keit.asc "$out/"

# pool/main/<first letter>/<package>/<file>.deb, as Debian lays it out.
downloads=$(mktemp -d)
grep -v '^\s*\(#\|$\)' apps.txt | while read -r repo; do
    # `gh release view` with no tag is the latest release that's neither a
    # draft nor a pre-release.
    tag=$(gh release view -R "$repo" --json tagName --jq .tagName)
    echo "$repo: $tag"
    rm -f "$downloads"/*
    gh release download "$tag" -R "$repo" -p '*.deb' -D "$downloads"
    for deb in "$downloads"/*.deb; do
        package=$(dpkg-deb -f "$deb" Package)
        mkdir -p "$out/pool/main/${package:0:1}/$package"
        mv "$deb" "$out/pool/main/${package:0:1}/$package/"
    done
done
rmdir "$downloads"

cd "$out"
for arch in "${archs[@]}"; do
    dir=dists/$suite/main/binary-$arch
    mkdir -p "$dir"
    apt-ftparchive --arch "$arch" packages pool/main > "$dir/Packages"
    gzip -9kn "$dir/Packages"
done

# Written outside dists/ first, or it would list itself.
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=keit \
    -o APT::FTPArchive::Release::Label="keit's apps" \
    -o APT::FTPArchive::Release::Suite=$suite \
    -o APT::FTPArchive::Release::Codename=$suite \
    -o APT::FTPArchive::Release::Architectures="${archs[*]}" \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Description="Linux apps by Kei Takashima (ZL2MIM)" \
    release "dists/$suite" > Release
mv Release "dists/$suite/Release"

gpg --batch --yes --local-user "$key" --clearsign -o "dists/$suite/InRelease" "dists/$suite/Release"
gpg --batch --yes --local-user "$key" --armor --detach-sign -o "dists/$suite/Release.gpg" "dists/$suite/Release"

# The page lists what's in the repository.
rows=$(for arch in "${archs[@]}"; do
    awk -v arch="$arch" '/^Package:/{p=$2} /^Version:/{v=$2} /^Description:/{sub(/^Description: /,""); print p "\t" v "\t" $0}' \
        "dists/$suite/main/binary-$arch/Packages"
done | sort -u -t$'\t' -k1,1 | awk -F'\t' '{printf "<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>\n", $1, $2, $3}')
python3 - "$rows" <<'EOF'
import sys
page = open("index.html").read().replace("<!-- PACKAGES -->", sys.argv[1])
open("index.html", "w").write(page)
EOF

echo "Built $(find pool -name '*.deb' | wc -l) packages into $out"
