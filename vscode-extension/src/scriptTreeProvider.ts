import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class ScriptTreeProvider implements vscode.TreeDataProvider<ScriptItem> {
    private _onDidChangeTreeData: vscode.EventEmitter<ScriptItem | undefined | null | void> = new vscode.EventEmitter<ScriptItem | undefined | null | void>();
    readonly onDidChangeTreeData: vscode.Event<ScriptItem | undefined | null | void> = this._onDidChangeTreeData.event;

    constructor(private context: vscode.ExtensionContext) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: ScriptItem): vscode.TreeItem {
        return element;
    }

    async getChildren(element?: ScriptItem): Promise<ScriptItem[]> {
        if (!element) {
            // Root level - show categories
            return this.getScriptCategories();
        } else {
            // Category level - show scripts
            return this.getScriptsInCategory(element.range);
        }
    }

    private async getScriptCategories(): Promise<ScriptItem[]> {
        const categories = [
            { label: 'Environment Prep', range: '0000-0099', description: 'PowerShell 7, directories' },
            { label: 'Infrastructure', range: '0100-0199', description: 'Hyper-V, certificates' },
            { label: 'Dev Tools', range: '0200-0299', description: 'Git, Node, Docker, VS Code' },
            { label: 'Testing', range: '0400-0499', description: 'Unit tests, quality checks' },
            { label: 'Reporting', range: '0500-0599', description: 'Reports, metrics' },
            { label: 'Dev Workflows', range: '0700-0799', description: 'Git workflows, CI/CD' },
            { label: 'Issue Management', range: '0800-0899', description: 'Issue tracking' },
            { label: 'Test Generation', range: '0900-0999', description: 'Automated tests' }
        ];

        return categories.map(cat => new ScriptItem(
            cat.label,
            cat.description,
            vscode.TreeItemCollapsibleState.Collapsed,
            cat.range
        ));
    }

    private async getScriptsInCategory(range: string): Promise<ScriptItem[]> {
        const aitherZeroPath = this.getAitherZeroPath();
        if (!aitherZeroPath) {
            return [];
        }

        const scriptsPath = path.join(aitherZeroPath, 'automation-scripts');
        if (!fs.existsSync(scriptsPath)) {
            return [];
        }

        const [start, end] = range.split('-').map(s => parseInt(s));
        const scripts: ScriptItem[] = [];

        const files = fs.readdirSync(scriptsPath);
        for (const file of files) {
            if (file.endsWith('.ps1')) {
                const match = file.match(/^(\d{4})_(.+)\.ps1$/);
                if (match) {
                    const number = parseInt(match[1]);
                    if (number >= start && number <= end) {
                        const name = match[2].replace(/-/g, ' ');
                        const scriptPath = path.join(scriptsPath, file);
                        scripts.push(new ScriptItem(
                            `${match[1]} - ${name}`,
                            '',
                            vscode.TreeItemCollapsibleState.None,
                            undefined,
                            {
                                command: 'aitherzero.runScript',
                                title: 'Run Script',
                                arguments: [{ number: match[1], path: scriptPath }]
                            },
                            match[1]
                        ));
                    }
                }
            }
        }

        return scripts.sort((a, b) => {
            const numA = parseInt(a.number || '0');
            const numB = parseInt(b.number || '0');
            return numA - numB;
        });
    }

    private getAitherZeroPath(): string | undefined {
        const config = vscode.workspace.getConfiguration('aitherzero');
        let installPath = config.get<string>('installationPath');

        if (!installPath || installPath === '') {
            // Auto-detect: check if we're in the AitherZero workspace
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

            // Check environment variable
            if (!installPath) {
                installPath = process.env.AITHERZERO_ROOT;
            }
        }

        return installPath;
    }
}

class ScriptItem extends vscode.TreeItem {
    constructor(
        public readonly label: string,
        public readonly description: string,
        public readonly collapsibleState: vscode.TreeItemCollapsibleState,
        public readonly range?: string,
        public readonly command?: vscode.Command,
        public readonly number?: string
    ) {
        super(label, collapsibleState);
        this.tooltip = `${this.label}${description ? ': ' + description : ''}`;
        this.contextValue = number ? 'script' : 'category';
        
        if (number) {
            this.iconPath = new vscode.ThemeIcon('file-code');
        } else {
            this.iconPath = new vscode.ThemeIcon('folder');
        }
    }
}
