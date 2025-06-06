#include "usbkeyboard.h"

#include <stdio.h>
#include <stdlib.h> 

/* References on libusb 1.0 and the USB HID/keyboard protocol
 *
 * http://libusb.org
 * https://web.archive.org/web/20210302095553/https://www.dreamincode.net/forums/topic/148707-introduction-to-using-libusb-10/
 *
 * https://www.usb.org/sites/default/files/documents/hid1_11.pdf
 *
 * https://usb.org/sites/default/files/hut1_5.pdf
 */

/*
 * Find and return a USB keyboard device or NULL if not found
 * The argument con
 * 
 */
// struct libusb_device_handle *openkeyboard(uint8_t *endpoint_address) {
//   libusb_device **devs;
//   struct libusb_device_handle *keyboard = NULL;
//   struct libusb_device_descriptor desc;
//   ssize_t num_devs, d;
//   uint8_t i, k;
  
//   /* Start the library */
//   if ( libusb_init(NULL) < 0 ) {
//     fprintf(stderr, "Error: libusb_init failed\n");
//     exit(1);
//   }

//   /* Enumerate all the attached USB devices */
//   if ( (num_devs = libusb_get_device_list(NULL, &devs)) < 0 ) {
//     fprintf(stderr, "Error: libusb_get_device_list failed\n");
//     exit(1);
//   }

//   /* Look at each device, remembering the first HID device that speaks
//      the keyboard protocol */

//   for (d = 0 ; d < num_devs ; d++) {
//     libusb_device *dev = devs[d];
//     if ( libusb_get_device_descriptor(dev, &desc) < 0 ) {
//       fprintf(stderr, "Error: libusb_get_device_descriptor failed\n");
//       exit(1);
//     }

//     if (desc.bDeviceClass == LIBUSB_CLASS_PER_INTERFACE) {
//       struct libusb_config_descriptor *config;
//       libusb_get_config_descriptor(dev, 0, &config);
//       for (i = 0 ; i < config->bNumInterfaces ; i++)	       
// 	for ( k = 0 ; k < config->interface[i].num_altsetting ; k++ ) {
// 	  const struct libusb_interface_descriptor *inter =
// 	    config->interface[i].altsetting + k ;
// 	  if ( inter->bInterfaceClass == LIBUSB_CLASS_HID &&
// 	       inter->bInterfaceProtocol == USB_HID_KEYBOARD_PROTOCOL) {
// 	    int r;
// 	    if ((r = libusb_open(dev, &keyboard)) != 0) {
// 	      fprintf(stderr, "Error: libusb_open failed: %d\n", r);
// 	      exit(1);
// 	    }
// 	    if (libusb_kernel_driver_active(keyboard,i))
// 	      libusb_detach_kernel_driver(keyboard, i);
// 	    libusb_set_auto_detach_kernel_driver(keyboard, i);
// 	    if ((r = libusb_claim_interface(keyboard, i)) != 0) {
// 	      // fprintf(stderr, "Error: libusb_claim_interface failed: %d\n", r);
//         fprintf(stderr, "Error: libusb_claim_interface failed: %s\n", libusb_error_name(r));
// 	      exit(1);
// 	    }
// 	    *endpoint_address = inter->endpoint[0].bEndpointAddress;
// 	    goto found;
// 	  }
// 	}
//     }
//   }

//  found:
//   libusb_free_device_list(devs, 1);

//   return keyboard;
// }
struct libusb_device_handle *openkeyboard(uint8_t *endpoint_address) {
  libusb_device **devs;
  struct libusb_device_handle *keyboard = NULL;
  struct libusb_device_descriptor desc;
  ssize_t num_devs;
  uint8_t i, k;
  int r;

  if ((r = libusb_init(NULL)) < 0) {
      fprintf(stderr, "libusb_init failed: %s\n", libusb_error_name(r));
      exit(1);
  }

  if ((num_devs = libusb_get_device_list(NULL, &devs)) < 0) {
      fprintf(stderr, "libusb_get_device_list failed: %s\n", libusb_error_name(num_devs));
      exit(1);
  }

  for (ssize_t d = 0; d < num_devs; d++) {
      libusb_device *dev = devs[d];
      if (libusb_get_device_descriptor(dev, &desc) < 0)
          continue;

      if (desc.bDeviceClass == LIBUSB_CLASS_PER_INTERFACE) {
          struct libusb_config_descriptor *config;
          libusb_get_config_descriptor(dev, 0, &config);

          for (i = 0; i < config->bNumInterfaces; i++) {
              for (k = 0; k < config->interface[i].num_altsetting; k++) {
                  const struct libusb_interface_descriptor *inter = &config->interface[i].altsetting[k];
                  if (inter->bInterfaceClass == LIBUSB_CLASS_HID &&
                      inter->bInterfaceProtocol == USB_HID_KEYBOARD_PROTOCOL) {

                      if ((r = libusb_open(dev, &keyboard)) != 0) {
                          fprintf(stderr, "libusb_open failed: %s\n", libusb_error_name(r));
                          continue;
                      }

                      // Detach kernel driver if needed
                      if (libusb_kernel_driver_active(keyboard, i) == 1) {
                          r = libusb_detach_kernel_driver(keyboard, i);
                          if (r != 0) {
                              fprintf(stderr, "libusb_detach_kernel_driver failed: %s\n", libusb_error_name(r));
                              libusb_close(keyboard);
                              continue;
                          }
                      }

                      libusb_set_auto_detach_kernel_driver(keyboard, 1);

                      if ((r = libusb_claim_interface(keyboard, i)) != 0) {
                          fprintf(stderr, "libusb_claim_interface failed: %s\n", libusb_error_name(r));
                          libusb_close(keyboard);
                          continue;
                      }

                      *endpoint_address = inter->endpoint[0].bEndpointAddress;
                      libusb_free_config_descriptor(config);
                      libusb_free_device_list(devs, 1);
                      return keyboard;
                  }
              }
          }

          libusb_free_config_descriptor(config);
      }
  }

  libusb_free_device_list(devs, 1);
  fprintf(stderr, "No USB keyboard found\n");
  return NULL;
}