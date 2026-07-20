package com.psyche.kelivo;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;

import androidx.annotation.Keep;

import java.io.File;
import java.nio.ByteBuffer;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

@Keep
public final class KelivoKeystoreBridge {
    private static final String KEYSTORE_PROVIDER = "AndroidKeyStore";
    private static final String WRAPPING_KEY_ALIAS = "kelivo.secure-core.v1.wrap";
    private static final String CIPHER_TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int LOCAL_KEY_SIZE = 32;
    private static final int GCM_IV_SIZE = 12;
    private static final int GCM_TAG_SIZE_BITS = 128;
    private static final int PROTECTED_KEY_VERSION = 1;
    private static final int PROTECTED_KEY_SIZE = 1 + GCM_IV_SIZE + LOCAL_KEY_SIZE + 16;
    private static final Object KEY_LOCK = new Object();
    private static volatile Context applicationContext;

    private KelivoKeystoreBridge() {
    }

    static void initialize(Context context) {
        applicationContext = context.getApplicationContext();
    }

    @Keep
    public static String getSlotRootPath() {
        final Context context = applicationContext;
        if (context == null) {
            throw new IllegalStateException("安全核心尚未完成进程初始化");
        }
        // 本地包装密文没有跨设备恢复价值，恢复后缺少 Keystore 根密钥只会形成死数据。
        return new File(
                context.getNoBackupFilesDir(),
                "Kelivo/secure-core/v1/slots"
        ).getAbsolutePath();
    }

    @Keep
    public static int encrypt(
            ByteBuffer plaintext,
            ByteBuffer associatedData,
            ByteBuffer output
    ) throws GeneralSecurityException {
        final ByteBuffer input = requireDirectInput(plaintext, LOCAL_KEY_SIZE, "plaintext");
        final ByteBuffer aad = requireDirectInput(associatedData, -1, "associatedData");
        final ByteBuffer target = requireDirectOutput(output, PROTECTED_KEY_SIZE);

        final Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateWrappingKey());
        final byte[] iv = cipher.getIV();
        if (iv == null || iv.length != GCM_IV_SIZE) {
            throw new GeneralSecurityException("Android Keystore 返回了异常的 GCM IV");
        }

        target.put((byte) PROTECTED_KEY_VERSION);
        target.put(iv);
        cipher.updateAAD(aad);
        final int encryptedSize = cipher.doFinal(input, target);
        if (encryptedSize != LOCAL_KEY_SIZE + 16 || target.position() != PROTECTED_KEY_SIZE) {
            throw new GeneralSecurityException("Android Keystore 返回了异常的包装密文长度");
        }
        return target.position();
    }

    @Keep
    public static int decrypt(
            ByteBuffer protectedKey,
            ByteBuffer associatedData,
            ByteBuffer output
    ) throws GeneralSecurityException {
        final ByteBuffer input = requireDirectInput(
                protectedKey,
                PROTECTED_KEY_SIZE,
                "protectedKey"
        );
        final ByteBuffer aad = requireDirectInput(associatedData, -1, "associatedData");
        final ByteBuffer target = requireDirectOutput(output, LOCAL_KEY_SIZE);

        final int version = Byte.toUnsignedInt(input.get());
        if (version != PROTECTED_KEY_VERSION) {
            throw new GeneralSecurityException("Android 包装密文版本不受支持");
        }
        final byte[] iv = new byte[GCM_IV_SIZE];
        input.get(iv);

        final Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
        cipher.init(
                Cipher.DECRYPT_MODE,
                getExistingWrappingKey(),
                new GCMParameterSpec(GCM_TAG_SIZE_BITS, iv)
        );
        cipher.updateAAD(aad);
        final int plaintextSize = cipher.doFinal(input, target);
        if (plaintextSize != LOCAL_KEY_SIZE || target.position() != LOCAL_KEY_SIZE) {
            throw new GeneralSecurityException("Android Keystore 返回了异常的明文长度");
        }
        return target.position();
    }

    private static ByteBuffer requireDirectInput(
            ByteBuffer buffer,
            int expectedSize,
            String name
    ) {
        if (buffer == null || !buffer.isDirect()) {
            throw new IllegalArgumentException(name + " 必须是 DirectByteBuffer");
        }
        if (expectedSize >= 0 && buffer.remaining() != expectedSize) {
            throw new IllegalArgumentException(name + " 长度不符合协议");
        }
        if (expectedSize < 0 && !buffer.hasRemaining()) {
            throw new IllegalArgumentException(name + " 不得为空");
        }
        return buffer.asReadOnlyBuffer();
    }

    private static ByteBuffer requireDirectOutput(ByteBuffer buffer, int expectedSize) {
        if (buffer == null || !buffer.isDirect() || buffer.isReadOnly()) {
            throw new IllegalArgumentException("output 必须是可写 DirectByteBuffer");
        }
        if (buffer.remaining() != expectedSize) {
            throw new IllegalArgumentException("output 长度不符合协议");
        }
        return buffer.duplicate();
    }

    private static SecretKey getOrCreateWrappingKey() throws GeneralSecurityException {
        synchronized (KEY_LOCK) {
            final KeyStore keyStore = loadKeyStore();
            final Key existing = keyStore.getKey(WRAPPING_KEY_ALIAS, null);
            if (existing != null) {
                return requireAesSecretKey(existing);
            }

            final KeyGenerator generator = KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES,
                    KEYSTORE_PROVIDER
            );
            generator.init(
                    new KeyGenParameterSpec.Builder(
                            WRAPPING_KEY_ALIAS,
                            KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
                    )
                            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                            .setKeySize(256)
                            .setRandomizedEncryptionRequired(true)
                            .setUserAuthenticationRequired(false)
                            .build()
            );
            return generator.generateKey();
        }
    }

    private static SecretKey getExistingWrappingKey() throws GeneralSecurityException {
        synchronized (KEY_LOCK) {
            final Key key = loadKeyStore().getKey(WRAPPING_KEY_ALIAS, null);
            if (key == null) {
                throw new GeneralSecurityException("Android Keystore 包装密钥不存在");
            }
            return requireAesSecretKey(key);
        }
    }

    private static KeyStore loadKeyStore() throws GeneralSecurityException {
        final KeyStore keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
        try {
            keyStore.load(null);
        } catch (java.io.IOException error) {
            throw new GeneralSecurityException("Android Keystore 无法加载", error);
        }
        return keyStore;
    }

    private static SecretKey requireAesSecretKey(Key key) throws GeneralSecurityException {
        if (!(key instanceof SecretKey) || !KeyProperties.KEY_ALGORITHM_AES.equals(key.getAlgorithm())) {
            throw new GeneralSecurityException("Android Keystore 包装密钥类型异常");
        }
        return (SecretKey) key;
    }
}
