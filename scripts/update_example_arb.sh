rm -rf example_flutter/assets/languages
dart test --name "cleaner works"
rsync -r test/files/temp/files_current/ example_flutter/assets/languages --delete