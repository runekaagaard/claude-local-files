# Claude Local Files

Serve local files to Claude via HTTPS. Uses a clever hack that passes the Claude desktop Electron app's Content Security Policy by intercepting requests to cdn.jsdelivr.net.

## How it works

1. Intercepts cdn.jsdelivr.net locally using /etc/hosts
2. Serves local files under /pyodide/* to match Claude's CSP whitelist
3. Proxies all other requests to the real CDN via Fastly
4. Uses mkcert for valid HTTPS certificates
5. Adds CORS headers for claudeusercontent.com

## Installation

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt update
sudo apt install mkcert caddy
```

### macOS

```bash
# Install dependencies
brew install mkcert caddy
```

## Project Structure
```
claude-local-files/
├── Caddyfile
├── claude-local-files.sh
├── files/
│   └── test.json
└── README.md
```

## Usage

1. Clone and enter the repository:
```bash
git clone https://github.com/runekaagaard/claude-local-files.git
cd claude-local-files
```

2. Add your files to the `files/` directory

3. Start the server:
```bash
./claude-local-files.sh
```

4. Access files in Claude desktop app artifacts using URL pattern:
```javascript
fetch('https://cdn.jsdelivr.net/pyodide/claude-local-files/your-file.json')
```

Example React artifact:
```javascript
import React, { useState, useEffect } from 'react';

const LocalJsonViewer = () => {
  const [data, setData] = useState(null);
  
  useEffect(() => {
    fetch('https://cdn.jsdelivr.net/pyodide/claude-local-files/test.json')
      .then(response => response.json())
      .then(setData)
      .catch(console.error);
  }, []);

  return <pre>{JSON.stringify(data, null, 2)}</pre>;
};

export default LocalJsonViewer;
```

## Testing

Test that the local server works:
```bash
curl -v https://cdn.jsdelivr.net/pyodide/claude-local-files/test.json
```

Test that CDN passthrough works:
```bash
curl -v https://cdn.jsdelivr.net/npm/jquery/dist/jquery.min.js
```

## Generating URLs

To serve a file:
1. Place it in the `files/` directory
2. Access it at `https://cdn.jsdelivr.net/pyodide/claude-local-files/[FILENAME]`

Example:
- File: `files/data.json`
- URL: `https://cdn.jsdelivr.net/pyodide/claude-local-files/data.json`

## Security Notes

- Only runs locally - the cdn.jsdelivr.net interception is only on your machine
- Uses proper HTTPS with valid certificates via mkcert
- Maintains Claude's security model by working within its CSP restrictions
- Scripts cleans up /etc/hosts modifications on exit
- Certificates are stored in the workspace directory

## Development

Pull requests welcome! Areas for improvement:
- Windows support
- Better logging options
- File watching/auto reload
- Configuration options

## License

Mozilla Public License
