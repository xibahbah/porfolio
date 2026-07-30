#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fputs("usage: image-sanitizer INPUT OUTPUT\n", stderr);
            return EXIT_FAILURE;
        }

        NSURL *inputURL =
            [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSURL *outputURL =
            [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
        CGImageSourceRef source =
            CGImageSourceCreateWithURL((__bridge CFURLRef)inputURL, NULL);
        if (!source) {
            fputs("image-sanitizer: cannot read input\n", stderr);
            return EXIT_FAILURE;
        }

        CGImageRef image =
            CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFStringRef type = CGImageSourceGetType(source);
        if (!image || !type) {
            if (image) {
                CGImageRelease(image);
            }
            CFRelease(source);
            fputs("image-sanitizer: unsupported image\n", stderr);
            return EXIT_FAILURE;
        }

        CGImageDestinationRef destination =
            CGImageDestinationCreateWithURL(
                (__bridge CFURLRef)outputURL,
                type,
                1,
                NULL
            );
        if (!destination) {
            CGImageRelease(image);
            CFRelease(source);
            fputs("image-sanitizer: cannot create output\n", stderr);
            return EXIT_FAILURE;
        }

        CGImageDestinationAddImage(destination, image, NULL);
        BOOL succeeded = CGImageDestinationFinalize(destination);

        CFRelease(destination);
        CGImageRelease(image);
        CFRelease(source);

        if (!succeeded) {
            fputs("image-sanitizer: cannot finalize output\n", stderr);
            return EXIT_FAILURE;
        }
    }
    return EXIT_SUCCESS;
}
