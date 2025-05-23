# Claude Local Files

Artifacts in Claude Desktop can only access cdn.jsdelivr.net/pyodide/* due to Content Security Policy restrictions. This app bypasses that restriction and allows Claude Desktop artifact and analysis tools to fetch local files and use them for calculations, UI's, etc.

I use it with [mcp-alchemy](https://github.com/runekaagaard/mcp-alchemy/) to have Claude Desktop generate UI reports for database result sets that are way too large for an LLM to read.

## How it works

1. Adds a line in /etc/hosts that points cdn.jsdelivr.net to 127.0.0.1
2. Uses mkcert to generate a valid local SSL certificate for cdn.jsdelivr.net
3. Starts a caddy server that proxies all other requests than to a specfic url folder to Fastly
4. Files in the `./files` directory are served at `https://cdn.jsdelivr.net/pyodide/claude-local-files/[FILENAME]`
4. Removes the line in /etc/hosts on exit

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


### Windows
Run in an elevated powershell (as administrator):
```powershell
# Install dependencies
winget install CaddyServer.Caddy
winget install FiloSottile.mkcert

# Run the script
./claude-local-files.ps1
``` 

## Usage

1. Clone and enter the repository:
```bash
git clone https://github.com/runekaagaard/claude-local-files.git
cd claude-local-files
```

2. Start the server:
```bash
./claude-local-files.sh
```

3. Add your files to the `files/` directory

4. Ask Claude Desktop to use the content of the file in a code artifact, e.g. https://cdn.jsdelivr.net/pyodide/claude-local-files/test.json

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
- File: `files/test.json`
- URL: `https://cdn.jsdelivr.net/pyodide/claude-local-files/test.json`

## Security Notes

- Only runs locally - the cdn.jsdelivr.net interception is only on your machine
- Uses proper HTTPS with valid certificates via mkcert
- Scripts cleans up /etc/hosts modifications on exit
- Certificates are stored in the git root directory

## Development

Pull requests welcome! Areas for improvement:

- Windows support
- Better logging options

## License

Mozilla Public License 2.0

## My Other LLM Projects

- **[MCP Alchemy](https://github.com/runekaagaard/mcp-alchemy)** - Connect Claude Desktop to databases for exploring schema and running SQL.
- **[MCP Redmine](https://github.com/runekaagaard/mcp-redmine)** - Let Claude Desktop manage your Redmine projects and issues.
- **[MCP Notmuch Sendmail](https://github.com/runekaagaard/mcp-notmuch-sendmail)** - Email assistant for Claude Desktop using notmuch.
- **[Diffpilot](https://github.com/runekaagaard/diffpilot)** - Multi-column git diff viewer with file grouping and tagging.
