### download and unzip ndk
sudo android-ndk-r19c-linux-x86_64.zip -d /opt/android-ndk/android-ndk-r19c
sudo ln -sfn /opt/android-ndk/android-ndk-r19c /opt/android-ndk/ndk

### build boost 1.67.0 for android 
sudo ./build_boost_android.sh 1 67 0

### plus 
wired thing is, sometimes build succcessful, but sometimes not.

### references
https://cedanet.com.au/ceda/xcpp/android/file.php?filename=buildboostandroid
https://github.com/dec1/Boost-for-Android

