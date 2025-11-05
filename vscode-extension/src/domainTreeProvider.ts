import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class DomainTreeProvider implements vscode.TreeDataProvider<DomainItem> {
    private _onDidChangeTreeData: vscode.EventEmitter<DomainItem | undefined | null | void> = new vscode.EventEmitter<DomainItem | undefined | null | void>();
    readonly onDidChangeTreeData: vscode.Event<DomainItem | undefined | null | void> = this._onDidChangeTreeData.event;

    constructor(private context: vscode.ExtensionContext) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: DomainItem): vscode.TreeItem {
        return element;
    }

    async getChildren(element?: DomainItem): Promise<DomainItem[]> {
        if (!element) {
            return this.getDomains();
        }
        return [];
    }

    async getDomains(): Promise<DomainItem[]> {
        const aitherZeroPath = this.getAitherZeroPath();
        if (!aitherZeroPath) {
            return [];
        }

        const domainsPath = path.join(aitherZeroPath, 'domains');
        if (!fs.existsSync(domainsPath)) {
            return [];
        }

        const domains: DomainItem[] = [];
        const dirs = fs.readdirSync(domainsPath, { withFileTypes: true });

        for (const dir of dirs) {
            if (dir.isDirectory()) {
                const domainPath = path.join(domainsPath, dir.name);
                const moduleFiles = fs.readdirSync(domainPath).filter(f => f.endsWith('.psm1'));
                const functionCount = this.countFunctionsInDomain(domainPath);
                
                domains.push(new DomainItem(
                    dir.name,
                    domainPath,
                    moduleFiles.length,
                    functionCount
                ));
            }
        }

        return domains;
    }

    private countFunctionsInDomain(domainPath: string): number {
        let count = 0;
        const files = fs.readdirSync(domainPath);
        
        for (const file of files) {
            if (file.endsWith('.psm1')) {
                const content = fs.readFileSync(path.join(domainPath, file), 'utf8');
                const matches = content.match(/^\s*function\s+[\w-]+/gm);
                if (matches) {
                    count += matches.length;
                }
            }
        }
        
        return count;
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

class DomainItem extends vscode.TreeItem {
    constructor(
        public readonly label: string,
        public readonly domainPath: string,
        public readonly moduleCount: number,
        public readonly functionCount: number
    ) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = `${moduleCount} modules, ${functionCount} functions`;
        this.tooltip = `Domain: ${label}\nModules: ${moduleCount}\nFunctions: ${functionCount}`;
        this.iconPath = new vscode.ThemeIcon('package');
        this.contextValue = 'domain';
        this.command = {
            command: 'vscode.open',
            title: 'Open Domain',
            arguments: [vscode.Uri.file(domainPath)]
        };
    }
}
