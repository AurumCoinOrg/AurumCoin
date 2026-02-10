#ifndef AURUM_CRYPTO_SCRYPT_H
#define AURUM_CRYPTO_SCRYPT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void scrypt_1024_1_1_256(const char* input, char* output);

#ifdef __cplusplus
}
#endif

#endif // AURUM_CRYPTO_SCRYPT_H
