# About upgrade_engine.ps1

<img width="1265" alt="Screenshot 2025-02-16 at 14 44 30" src="https://github.com/user-attachments/assets/ecf7fb46-08e0-4e4b-9658-bc6753804a70" />

According to Microsoft, Windows 10 will reach its "end of life" on October 14, 2025. After this date, Microsoft will no longer provide security updates, technical support, or new features for the operating system.

Now, let’s say your company doesn't have the budget to invest in a centralized system for deploying Windows updates across both supported and unsupported hardware to Windows 11. As an administrator, you've identified over 1,000 computers running Windows 10 within your company’s network.

To tackle this challenge and avoid unnecessary costs, **Upgrade_Engine.ps1** comes into play.

What is **Upgrade_Engine.ps1**?
Upgrade_Engine.ps1 is a PowerShell script developed by **AuxGrep** to help administrators seamlessly upgrade Windows 10 workstations to Windows 11 Pro. It works silently via Group Policy from a Domain Controller (DC), using a single Windows 11 ISO file shared over the local network—no internet required.

**How Does It Work?**
1. Automatically copies the shared Windows 11 ISO to the user’s PC.
2. Initiates the upgrade process silently—users won't be asked any questions.
3. Keeps all user files intact—no data loss or manual intervention required.

Once the upgrade is complete, it notifies the user to restart their machine.
Even after the restart, the script continues managing the process—ensuring a smooth transition.
**No need for manual input, no complicated steps—just tell your users to sit back, grab a beer, and relax!** 🍻
