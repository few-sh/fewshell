# Decamp client app

## MacOS Development

### Code Signing

If you encounter code signing errors related to device registration, you may need to register your Mac's UUID in the Apple Developer Portal.

To get your Mac's Hardware UUID, run the following command in your terminal:

```bash
system_profiler SPHardwareDataType | grep "Hardware UUID"
```

1. Log in to the Apple Developer Portal at https://developer.apple.com/account
2. Go to Certificates, Identifiers & Profiles > Devices.
3. Click the + button to register a new device.
4. Enter your Mac's Name and UUID (you can find the UUID in "System Information" > "Hardware UUID"
5. Once registered, run the build again. Xcode should now successfully create the "Mac App Development" profile automatically.
