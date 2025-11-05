import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class PlaybookTreeProvider implements vscode.TreeDataProvider<PlaybookItem> {
    private _onDidChangeTreeData: vscode.EventEmitter<PlaybookItem | undefined | null | void> = new vscode.EventEmitter<PlaybookItem | undefined | null | void>();
    readonly onDidChangeTreeData: vscode.Event<PlaybookItem | undefined | null | void> = this._onDidChangeTreeData.event;

    constructor(private context: vscode.ExtensionContext) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: PlaybookItem): vscode.TreeItem {
        return element;
    }

    async getChildren(element?: PlaybookItem): Promise<PlaybookItem[]> {
        if (!element) {
            return this.getPlaybooks();
        }
        return [];
    }

    async getPlaybooks(): Promise<PlaybookItem[]> {
        const aitherZeroPath = this.getAitherZeroPath();
        if (!aitherZeroPath) {
            return [];
        }

        const playbooksPath = path.join(aitherZeroPath, 'orchestration', 'playbooks');
        if (!fs.existsSync(playbooksPath)) {
            return [];
        }

        const playbooks: PlaybookItem[] = [];
        const files = fs.readdirSync(playbooksPath, { withFileTypes: true });

        for (const file of files) {
            if (file.isFile() && (file.name.endsWith('.psd1') || file.name.endsWith('.json'))) {
                const name = path.parse(file.name).name;
                const fullPath = path.join(playbooksPath, file.name);
                playbooks.push(new PlaybookItem(
                    name,
                    fullPath,
                    {
                        command: 'aitherzero.openPlaybook',
                        title: 'Run Playbook',
                        arguments: [{ name, path: fullPath }]
                    }
                ));
            }
        }

        return playbooks;
    }

    getPlaybookNames(): string[] {
        const aitherZeroPath = this.getAitherZeroPath();
        if (!aitherZeroPath) {
            return [];
        }

        const playbooksPath = path.join(aitherZeroPath, 'orchestration', 'playbooks');
        if (!fs.existsSync(playbooksPath)) {
            return [];
        }

        const files = fs.readdirSync(playbooksPath, { withFileTypes: true });
        return files
            .filter(file => file.isFile() && (file.name.endsWith('.psd1') || file.name.endsWith('.json')))
            .map(file => path.parse(file.name).name);
    }

    private getAitherZeroPath(): string | undefined {
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

            if (!installPath) {
                installPath = process.env.AITHERZERO_ROOT;
            }
        }

        return installPath;
    }
}

class PlaybookItem extends vscode.TreeItem {
    constructor(
        public readonly label: string,
        public readonly playbookPath: string,
        public readonly command?: vscode.Command
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.tooltip = `Run playbook: ${label}`;
        this.iconPath = new vscode.ThemeIcon('play-circle');
        this.contextValue = 'playbook';
    }
}
