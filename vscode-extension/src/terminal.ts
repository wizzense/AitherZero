import * as vscode from 'vscode';
import * as path from 'path';

export class AitherZeroTerminal {
    private terminal: vscode.Terminal | undefined;

    private getOrCreateTerminal(): vscode.Terminal {
        if (!this.terminal || this.terminal.exitStatus !== undefined) {
            this.terminal = vscode.window.createTerminal({
                name: 'AitherZero',
                iconPath: new vscode.ThemeIcon('terminal-powershell')
            });
        }
        return this.terminal;
    }

    async runScript(scriptNumber: string, args: string[] = []): Promise<void> {
        const terminal = this.getOrCreateTerminal();
        const config = vscode.workspace.getConfiguration('aitherzero');
        
        if (config.get('terminal.clearBeforeRun')) {
            terminal.sendText('clear');
        }

        const command = this.buildScriptCommand(scriptNumber, args);
        terminal.show();
        terminal.sendText(command);

        if (config.get('showNotifications')) {
            vscode.window.showInformationMessage(`Running AitherZero script ${scriptNumber}...`);
        }
    }

    async runCommand(script: string, args: string[] = []): Promise<void> {
        const terminal = this.getOrCreateTerminal();
        const aitherZeroPath = this.getAitherZeroPath();
        
        if (!aitherZeroPath) {
            vscode.window.showErrorMessage('AitherZero installation path not found');
            return;
        }

        const scriptPath = path.join(aitherZeroPath, script);
        const command = `pwsh -File "${scriptPath}" ${args.join(' ')}`;
        
        terminal.show();
        terminal.sendText(command);
    }

    async runPlaybook(playbookName: string): Promise<void> {
        const terminal = this.getOrCreateTerminal();
        const aitherZeroPath = this.getAitherZeroPath();
        
        if (!aitherZeroPath) {
            vscode.window.showErrorMessage('AitherZero installation path not found');
            return;
        }

        const startScript = path.join(aitherZeroPath, 'Start-AitherZero.ps1');
        const command = `pwsh -File "${startScript}" -Mode Orchestrate -Playbook ${playbookName}`;
        
        terminal.show();
        terminal.sendText(command);

        vscode.window.showInformationMessage(`Running playbook: ${playbookName}`);
    }

    private buildScriptCommand(scriptNumber: string, args: string[] = []): string {
        const aitherZeroPath = this.getAitherZeroPath();
        
        if (!aitherZeroPath) {
            return `aitherzero ${scriptNumber} ${args.join(' ')}`;
        }

        // Try to use the global aitherzero command first, fall back to direct execution
        // Ensure args are passed to both the CLI and the fallback command
        const argsStr = args.length > 0 ? ` ${args.join(' ')}` : '';
        return `aitherzero ${scriptNumber}${argsStr} || pwsh -File "${path.join(aitherZeroPath, 'Start-AitherZero.ps1')}" -Mode Run -Target ${scriptNumber}${argsStr}`;
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

import * as fs from 'fs';
