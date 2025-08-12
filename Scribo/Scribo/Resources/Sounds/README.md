# Scribo Sound System

This directory contains sound resources and documentation for the Scribo app's audio feedback system.

## Sound Files

### pleasant-done-notification.wav
- **Author**: nckn
- **Source**: https://freesound.org/s/256112/
- **License**: Attribution NonCommercial 4.0
- **Usage**: Played when certain actions are completed successfully to provide user feedback

## Implementation

The sound system is implemented through the `SoundManager` class located at `Utilities/SoundManager.swift`.

### Available Sounds

1. **Completion Sound**: `playCompletionSound()`
   - Plays the pleasant-done-notification.wav file
   - Used for successful action feedback

2. **Shutter Sound**: `playShutterSound()`
   - Plays the system camera shutter sound (SystemSoundID: 1108)
   - Used when capturing photos in the camera view

3. **System Sounds**: `playSystemSound(_ soundID: SystemSoundID)`
   - Plays any iOS system sound by ID
   - Available for future sound implementations

### Usage Examples

```swift
// Play completion sound
SoundManager.shared.playCompletionSound()

// Play camera shutter sound
SoundManager.shared.playShutterSound()

// Play system sound
SoundManager.shared.playSystemSound(1108) // Camera shutter
```

## Adding New Sounds

To add new sounds to the system:

1. Add the sound file to the appropriate directory
2. Update the `SoundManager` class with new audio player properties
3. Create setup methods for the new sounds
4. Add public methods to play the sounds
5. Update this documentation

## License Compliance

All sound files must have proper licensing documentation. See `LICENSE.txt` for details on the current sound file's license requirements.
