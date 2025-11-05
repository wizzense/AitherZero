import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class DashboardPanel {
    public static currentPanel: DashboardPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private readonly _extensionUri: vscode.Uri;
    private _disposables: vscode.Disposable[] = [];

    public static createOrShow(extensionUri: vscode.Uri) {
        const column = vscode.window.activeTextEditor
            ? vscode.window.activeTextEditor.viewColumn
            : undefined;

        if (DashboardPanel.currentPanel) {
            DashboardPanel.currentPanel._panel.reveal(column);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'aitherzeroDashboard',
            'AitherZero Dashboard',
            column || vscode.ViewColumn.One,
            {
                enableScripts: true,
                retainContextWhenHidden: true
            }
        );

        DashboardPanel.currentPanel = new DashboardPanel(panel, extensionUri);
    }

    private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri) {
        this._panel = panel;
        this._extensionUri = extensionUri;

        this._update();

        this._panel.onDidDispose(() => this.dispose(), null, this._disposables);
    }

    public dispose() {
        DashboardPanel.currentPanel = undefined;

        this._panel.dispose();

        while (this._disposables.length) {
            const x = this._disposables.pop();
            if (x) {
                x.dispose();
            }
        }
    }

    private _update() {
        this._panel.webview.html = this._getHtmlForWebview();
    }

    private _getHtmlForWebview() {
        const stats = this.getProjectStats();

        return `<!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AitherZero Dashboard</title>
            <style>
                body {
                    font-family: var(--vscode-font-family);
                    color: var(--vscode-foreground);
                    background-color: var(--vscode-editor-background);
                    padding: 20px;
                }
                .header {
                    border-bottom: 2px solid var(--vscode-panel-border);
                    padding-bottom: 15px;
                    margin-bottom: 20px;
                }
                h1 {
                    margin: 0;
                    color: var(--vscode-foreground);
                }
                .stats-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 15px;
                    margin-bottom: 30px;
                }
                .stat-card {
                    background-color: var(--vscode-editor-inactiveSelectionBackground);
                    border: 1px solid var(--vscode-panel-border);
                    border-radius: 8px;
                    padding: 15px;
                }
                .stat-value {
                    font-size: 32px;
                    font-weight: bold;
                    color: var(--vscode-textLink-foreground);
                }
                .stat-label {
                    font-size: 14px;
                    color: var(--vscode-descriptionForeground);
                    margin-top: 5px;
                }
                .actions {
                    display: flex;
                    gap: 10px;
                    flex-wrap: wrap;
                }
                button {
                    background-color: var(--vscode-button-background);
                    color: var(--vscode-button-foreground);
                    border: none;
                    padding: 10px 20px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 14px;
                }
                button:hover {
                    background-color: var(--vscode-button-hoverBackground);
                }
                .section {
                    margin-top: 30px;
                }
                .section h2 {
                    color: var(--vscode-foreground);
                    margin-bottom: 15px;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🚀 AitherZero Dashboard</h1>
                <p>Infrastructure Automation Platform</p>
            </div>

            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value">${stats.scripts}</div>
                    <div class="stat-label">Automation Scripts</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">${stats.domains}</div>
                    <div class="stat-label">Domains</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">${stats.playbooks}</div>
                    <div class="stat-label">Playbooks</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">${stats.functions}</div>
                    <div class="stat-label">Functions</div>
                </div>
            </div>

            <div class="section">
                <h2>Quick Actions</h2>
                <div class="actions">
                    <button onclick="runBootstrap()">🔧 Run Bootstrap</button>
                    <button onclick="validateSyntax()">✓ Validate Syntax</button>
                    <button onclick="runTests()">🧪 Run Tests</button>
                    <button onclick="refreshView()">🔄 Refresh</button>
                </div>
            </div>

            <div class="section">
                <h2>Recent Activity</h2>
                <p>Script execution history will appear here...</p>
            </div>

            <script>
                const vscode = acquireVsCodeApi();
                
                function runBootstrap() {
                    vscode.postMessage({ command: 'bootstrap' });
                }
                
                function validateSyntax() {
                    vscode.postMessage({ command: 'validateSyntax' });
                }
                
                function runTests() {
                    vscode.postMessage({ command: 'runTests' });
                }
                
                function refreshView() {
                    vscode.postMessage({ command: 'refresh' });
                }
            </script>
        </body>
        </html>`;
    }

    private getProjectStats(): { scripts: number; domains: number; playbooks: number; functions: number } {
        const config = vscode.workspace.getConfiguration('aitherzero');
        let installPath = config.get<string>('installationPath');

        if (!installPath || installPath === '') {
            const workspaceFolders = vscode.workspace.workspaceFolders;
            if (workspaceFolders) {
                for (const folder of workspaceFolders) {
                    const manifestPath = path.join(folder.uri.fsPath, 'AitherZero.psd1');
                    if (fs.existsSync(manifestPath)) {
                        installPath = folder.uri.fsPath;
                        break;
                    }
                }
            }
        }

        if (!installPath) {
            return { scripts: 0, domains: 0, playbooks: 0, functions: 0 };
        }

        let scripts = 0;
        let domains = 0;
        let playbooks = 0;
        let functions = 0;

        // Count scripts
        const scriptsPath = path.join(installPath, 'automation-scripts');
        if (fs.existsSync(scriptsPath)) {
            scripts = fs.readdirSync(scriptsPath).filter(f => f.endsWith('.ps1')).length;
        }

        // Count domains
        const domainsPath = path.join(installPath, 'domains');
        if (fs.existsSync(domainsPath)) {
            domains = fs.readdirSync(domainsPath, { withFileTypes: true })
                .filter(d => d.isDirectory()).length;
        }

        // Count playbooks
        const playbooksPath = path.join(installPath, 'orchestration', 'playbooks');
        if (fs.existsSync(playbooksPath)) {
            playbooks = fs.readdirSync(playbooksPath)
                .filter(f => f.endsWith('.psd1') || f.endsWith('.json')).length;
        }

        // Estimate functions (simplified)
        functions = 192; // From manifest, can be calculated dynamically

        return { scripts, domains, playbooks, functions };
    }
}
