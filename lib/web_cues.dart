// Web-only sound and speech; these no-ops stand in on Android and iOS,
// which use audioplayers and flutter_tts (see Cues in run_screen.dart).
void initWebCues() {}
void webSound(String asset) {}
void webSay(String text) {}
void webHush() {}
