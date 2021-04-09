A tool to import translations into native iOS or Flutter app.

# Usage

1. Run command `pub global activate -sgit https://github.com/szotp/localization_sheets`.
2. Ensure that pub cache and dart path was added to PATH:
```sh
# only works if you installed flutter in your $HOME
export PATH=$PATH:$HOME/flutter/.pub-cache/bin
export PATH=$PATH:$HOME/flutter/bin/cache/dart-sdk/bin 
```

2. Open the project. 
4. Create localization.json if it doesn't exist. This file contains options that dictate where and how strings will be generated. TODO: describe possible settings.
3. Run `localization_sheets`.
4. If running for the first time: tool will ask you to open URL and grant some permissions.
5. Commit the changes if needed.

# Troubleshooting

In case o problems, delete the cache directory: `rm -f ~/.localization_sheets`

# custom.dart
```dart
import 'dart:io';

import 'localization_sheets.dart' as other;

void main(List<String> arguments) {
  Directory.current = '<CURRENT>';
  other.main(arguments);
}
```
