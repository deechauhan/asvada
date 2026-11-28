# TestFlight builds

Every release the **Release** workflow makes is also archived, signed and uploaded to App Store
Connect by its `testflight` job, so it turns up in TestFlight on your phone. A release is made on
every merge to `main` (a patch bump) and when a milestone closes (see `release.yml`).

- **Version:** the release tag, e.g. `v0.1.4` → 0.1.4.
- **Build number:** the workflow's run number, which only goes up.
- **Signing:** Xcode's cloud-managed signing, authorised by an App Store Connect API key. No
  certificate or provisioning profile is kept in the repo or in secrets.
- **Film search:** TestFlight builds include the TMDB key (they're private). The public `.ipa` on
  the GitHub release still doesn't.
- **Testers:** builds are marked internal-only, for you and anyone on your App Store Connect team.

Until the secrets below are set, the job skips with a notice and the rest of the release goes
ahead as before.

## One-time setup (owner)

1. **Apple Developer Program.** A paid membership (99 USD a year) is needed for TestFlight.
   Note your **Team ID** (developer.apple.com → Account → Membership details).
2. **Register the bundle id.** developer.apple.com → Certificates, IDs & Profiles → Identifiers →
   **+** → App IDs → App, Bundle ID (explicit) `app.artifacts.Artifacts`. Turn on no extra
   capabilities.
3. **Create the app in App Store Connect.** appstoreconnect.apple.com → Apps → **+** → New App:
   platform iOS, name *Artifacts* (if the name is taken on the store, use e.g. *Artifacts:
   Savour* — the home-screen name stays *Artifacts*), primary language, the bundle id from step 2,
   any SKU (e.g. `artifacts`).
4. **API key.** App Store Connect → Users and Access → Integrations → App Store Connect API →
   Team Keys → **+**. Name it `GitHub Actions`, access **Admin** (cloud-managed signing needs to
   create the distribution certificate; App Manager can't). Download the `.p8` (you only get one
   chance) and note the **Key ID** and the **Issuer ID** at the top of the page.
5. **GitHub secrets.** Repo → Settings → Secrets and variables → Actions → New repository secret:

   | Secret | Value |
   |---|---|
   | `APP_STORE_CONNECT_KEY_ID` | the Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID |
   | `APP_STORE_CONNECT_API_KEY` | the whole contents of the `.p8` file, including the BEGIN/END lines |
   | `APPLE_TEAM_ID` | the Team ID |
   | `TMDB_API_KEY` | already set for CI; reused |

   Or from a terminal: `gh secret set APP_STORE_CONNECT_API_KEY < AuthKey_XXXXXXXXXX.p8`.
6. **First build.** Actions → Release → Run workflow, with a version higher than the latest tag.
   Processing in App Store Connect takes about 5–15 minutes. Then install the **TestFlight** app on
   your iPhone, sign in with the same Apple Account, and the build is there. Later builds arrive
   on their own after each merge; turn on automatic updates in TestFlight to get them without a tap.

## When it fails

- *No profiles for 'app.artifacts.Artifacts' were found* — step 2 is missing, or the key isn't
  Admin.
- *Cloud signing permission error* — the key's access level; recreate it as Admin.
- *The bundle version must be higher* — someone uploaded a build by hand with a larger build
  number. Re-run the workflow until the run number is past it, or upload again by hand.
- *Missing export compliance* — `ITSAppUsesNonExemptEncryption` is set to `NO` in `project.yml`
  (the app only uses HTTPS), so this shouldn't come up.
