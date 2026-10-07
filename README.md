# keit APT repository

APT repository for my Linux apps, published at <https://keit.github.io/apt>.
Set-up instructions for users are on that page.

## How it works

`.github/workflows/publish.yml` runs every 6 hours, on pushes to `main`, and by
hand (`gh workflow run -R keit/apt publish.yml`). It runs `build-repo.sh`,
which downloads the `.deb` files from the latest published release (not drafts
or pre-releases) of every repository in [apps.txt](apps.txt), generates the
index with `apt-ftparchive`, and signs it. The result is published to GitHub
Pages, then installed from on clean Debian and Ubuntu images as a test.

Nothing is stored in git except the script, `apps.txt`, the page and the
public key: the repository is rebuilt from the releases every time, so it
always carries each app's latest version.

To add an app: add its GitHub repository to `apps.txt`. Its releases need to
attach `.deb` files.

## Signing key

ed25519, fingerprint `2F13 9F75 C569 FA77 1904 732E E594 4DBB D89D D18E`, no
expiry. The public key is [keit.gpg](keit.gpg) (binary, what users install) and
[keit.asc](keit.asc) (armored). The private key is the `APT_SIGNING_KEY`
repository secret, with an offline backup.
