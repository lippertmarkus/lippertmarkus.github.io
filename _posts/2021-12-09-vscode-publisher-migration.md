---
title: "Migrating a VS Code Extension to another Publisher"
image: "/img/thumbnails/vsc-deprecated-to-vsc.png"
bigimg: "/img/vsc-deprecated.png"
tags: [Programming] 
---

If you're a VS Code extension developer and having the need to migrate your VS Code extension to another publisher, you might found that there's no official, standard or automated way to easily do that.

Instead there are only some [rough descriptions](https://github.com/microsoft/vscode/issues/21478#issuecomment-283118349) on manually deprecating the old version and then [publishing the extension to a new publisher](https://github.com/microsoft/vscode/issues/3670#issuecomment-191767639) but no real code examples or detailed instructions. We recently successfully did such a migration for an extension with more than 400 daily users and I would like to share with you the steps we took and how we automated the migration for existing users to make it as convenient as possible for them.

## Fundamentals

The publisher ID is part of the fully qualified identifier of the extension. When migrating to a different publisher, the extension identifier changes as well, e.g. from `oldPublisher.myextension` to `newPublisher.myextension`. 

Due to that, the extension under the new publisher will no longer be connected to the extension under the old publisher, hence it is a completely new extension. The challenge is to migrate the existing users and making it clear that the old extension should not be used anymore. Instead it should be uninstalled and replaced by the new extension.

The idea is to publish the extension under the new publisher, deprecate the old extension and point users to new one. To migrate as many users as possible to the new extension, we additionally make upgrading for them as comfortable and automated as possible. Let's look at the steps in detail.


## Step 1: Publishing the extension under the new publisher

The initial step is to publish the extension under the new publisher. For this you first need to change the publisher field in the `package.json` file of the extension:

```diff
{
    "name": "myextension",
-   "publisher": "oldPublisher",
+   "publisher": "newPublisher",
     ...
}
```

Based on this example the old identifier would be `oldPublisher.myextension` and the new one `newPublisher.myextension`. Apart from the change in the `package.json`, also have a look at the rest of the source code for references to the old identifier. Depending on your extension you might need to update references in automated tests (where you activate your extension before testing it by its identifier) or in other places.

Assuming you already [have access to the new publisher](https://docs.microsoft.com/en-us/visualstudio/extensibility/walkthrough-publishing-a-visual-studio-extension?view=vs-2022#add-additional-users-to-manage-your-publisher-account) you can now publish the extension under the new publisher using [`vsce publish`](https://code.visualstudio.com/api/working-with-extensions/publishing-extension) or upload the VSIX created by [`vsce package`](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#packaging-extensions) [via the Visual Studio Marketplace](https://docs.microsoft.com/en-us/visualstudio/extensibility/walkthrough-publishing-a-visual-studio-extension?view=vs-2022#publish-the-extension-to-visual-studio-marketplace).

Afterwards make sure to update all links e.g. on websites, documentations and also in VS Code workspace recommendations to point to the extension under the new publisher with the new identifier. With that you make sure that new users will directly install the new extension. Now let's also transition your existing users to that new extension.


## Step 2: Deprecating the old extension and automating migration for users

For existing users and people seeing your old extension in the marketplace you need to make clearly visible that this old extension is deprecated and that the new extension is the one to be used. We also want as many existing users as possible to migrate to the new extension and therefore need to make upgrading for them as comfortable and automated as possible.

Regarding the visible deprecation status, there's no built-in way to hide the old extension in the marketplace or to show it as deprecated. We therefore *manually* mark the old extension as deprecated by updating the `displayName` in the `package.json` for the next and last version of the old extension:

```diff
{
    "name": "myextension",
-   "displayName": "My Extension",
-   "version": "0.11.42",
+   "displayName": "[DEPRECATED] My Extension",
+   "version": "0.11.43",
     ...
}
```

It also helps to add a notice to the `README.md` with a link to the new extension as it's visible in the marketplace:

```diff
# My Extension

+ > ❗ **IMPORTANT** ❗ \
+ > **This extension was migrated to a new publisher. Please uninstall it and install [the new extension](https://marketplace.visualstudio.com/items?itemName=newPublisher.myextension) instead.**
...
```

With that the deprecation status should be clearly visible for existing users in the extension list and for others seeing it in the marketplace:

<div class="center" markdown="1">
  <img class="lazy" alt="Deprecated extension in the extension list and marketplace" data-src="/assets/posts/vscode-publisher-migration/deprecated.png" />
</div>

To now support the migration of existing users we show them a warning an action to automatically uninstall the old and install the new extension. This can be done by adding the following code to the `activate` function of the extension:

```typescript
export async function activate(extensionContext: vscode.ExtensionContext) {
    
	const updateNowItem = { title: 'Upgrade now' };
	await vscode.window.showWarningMessage("The extension was migrated to a new publisher. Please upgrade now.", updateNowItem).then(async (value) => {
		if (value === updateNowItem) {
			let uninstallOld = vscode.commands.executeCommand('workbench.extensions.uninstallExtension', 'oldPublisher.myextension');
			let installNew = vscode.commands.executeCommand('workbench.extensions.installExtension', 'newPublisher.myextension');
			await Promise.all([uninstallOld, installNew]);
			vscode.commands.executeCommand("workbench.action.reloadWindow");
		}
	});
    // ...
}
```

<div class="center" markdown="1">
  <img class="lazy" alt="Notification with action to automatically migrate to the new extension" data-src="/assets/posts/vscode-publisher-migration/update-notification.png" width="70%" />
</div>

With that changes, now publish this new and last version of the old extension under the old publisher like you did for the new extension in the first step. The next time the users use your extension they will see the deprecation status and will be able to easily upgrade to the new extension automatically in a matter of seconds.

### Conclusion

When possible try to publish your extension under an appropriate publisher right from the beginning. This saves you the work for migration and especially for updating all existing old references. 

If you still find yourself in a situation where you want to migrate your extension to another publisher, you can easily follow the two steps above. This automated migration path worked very well for our extension with more than 400 daily extension users.