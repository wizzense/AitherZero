import * as vscode from 'vscode';
import { ScriptTreeProvider } from './scriptTreeProvider';
import { PlaybookTreeProvider } from './playbookTreeProvider';
import { DomainTreeProvider } from './domainTreeProvider';
import { AitherZeroTerminal } from './terminal';
import { DashboardPanel } from './dashboardPanel';

export function activate(context: vscode.ExtensionContext) {
    console.log('AitherZero extension is now active');

    // Initialize providers
    const scriptProvider = new ScriptTreeProvider(context);
    const playbookProvider = new PlaybookTreeProvider(context);
    const domainProvider = new DomainTreeProvider(context);
    const terminal = new AitherZeroTerminal();

    // Register tree views
    vscode.window.registerTreeDataProvider('aitherZeroScripts', scriptProvider);
    vscode.window.registerTreeDataProvider('aitherZeroPlaybooks', playbookProvider);
    vscode.window.registerTreeDataProvider('aitherZeroDomains', domainProvider);

    // Set context for when extension is enabled
    vscode.commands.executeCommand('setContext', 'aitherzero:enabled', true);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.runScript', async (script) => {
            const scriptNumber = script?.number || await vscode.window.showInputBox({
                prompt: 'Enter script number (e.g., 0402)',
                placeHolder: '0402'
            });
            
            if (scriptNumber) {
                await terminal.runScript(scriptNumber);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.openDashboard', () => {
            DashboardPanel.createOrShow(context.extensionUri);
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.refreshScripts', () => {
            scriptProvider.refresh();
            playbookProvider.refresh();
            domainProvider.refresh();
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.bootstrap', async () => {
            await terminal.runCommand('bootstrap.ps1', ['-Mode', 'Update']);
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.validateSyntax', async () => {
            await terminal.runScript('0407', ['-All']);
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.runTests', async () => {
            await terminal.runScript('0402');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('aitherzero.openPlaybook', async (playbook) => {
            const playbookName = playbook?.name || await vscode.window.showQuickPick(
                playbookProvider.getPlaybookNames(),
                { placeHolder: 'Select a playbook to run' }
            );
            
            if (playbookName) {
                await terminal.runPlaybook(playbookName);
            }
        })
    );

    // Watch for configuration changes
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration(e => {
            if (e.affectsConfiguration('aitherzero')) {
                scriptProvider.refresh();
            }
        })
    );

    // Watch for file changes in automation-scripts directory
    const config = vscode.workspace.getConfiguration('aitherzero');
    if (config.get('autoRefresh')) {
        const watcher = vscode.workspace.createFileSystemWatcher('**/automation-scripts/**/*.ps1');
        watcher.onDidCreate(() => scriptProvider.refresh());
        watcher.onDidDelete(() => scriptProvider.refresh());
        watcher.onDidChange(() => scriptProvider.refresh());
        context.subscriptions.push(watcher);
    }
}

export function deactivate() {
    console.log('AitherZero extension is now deactivated');
}
