A tool to import translations into native iOS or Flutter app.

# Usage

1. Run command `flutter pub global activate -sgit https://github.com/szotp/localization_sheets`.
2. Ensure that `~/.pub-cache/bin/` was added to PATH.
2. Open the project. 
4. Create localization.json if it doesn't exist. This file contains options that dictate where and how strings will be generated. TODO: describe possible settings.
3. Run `localization_sheets`.
4. If running for the first time: tool will ask you to open URL and grant some permissions.
5. Commit the changes if needed.
