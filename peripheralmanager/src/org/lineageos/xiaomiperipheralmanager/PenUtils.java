/*
 * Copyright (C) 2023 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.xiaomiperipheralmanager;

import android.content.Context;
import android.hardware.input.InputManager;
import android.hardware.input.InputManager.InputDeviceListener;
import android.os.SystemProperties;
import android.util.Log;
import android.view.InputDevice;

import android.preference.PreferenceManager;
import android.content.SharedPreferences;

public class PenUtils {

    private static final String TAG = "XiaomiPeripheralManagerPenUtils";
    private static final boolean DEBUG = false;

    private static final int penVendorId = 6421;
    private static final int penProductId = 19841;

    private static InputManager mInputManager;

    private static final String STYLUS_KEY = "stylus_switch_key";

    private static SharedPreferences preferences;
    private static RefreshUtils mRefreshUtils;

    public static void setup(Context context) {
        mInputManager = (InputManager) context.getSystemService(Context.INPUT_SERVICE);
        mInputManager.registerInputDeviceListener(mInputDeviceListener, null);
        preferences = PreferenceManager.getDefaultSharedPreferences(context);
        mRefreshUtils = new RefreshUtils(context);
        refreshPenMode();
    }

    public static void enablePenMode() {
        Log.d(TAG, "enablePenMode: Enable Pen Mode");
        SystemProperties.set("persist.vendor.parts.pen", "18");
        Log.d(TAG, "enablePenMode: Setting Refresh Rates for Pen");
        mRefreshUtils.setPenRefreshRate();
    }

    public static void disablePenMode() {
        Log.d(TAG, "disablePenMode: Disable Pen Mode");
        SystemProperties.set("persist.vendor.parts.pen", "2");
        Log.d(TAG, "disablePenMode: Resetting Refresh Rate Values");
        mRefreshUtils.setDefaultRefreshRate();
    }

    private static void refreshPenMode() {
        for (int id : mInputManager.getInputDeviceIds()) {
            if (isDeviceXiaomiPen(id) || preferences.getBoolean(STYLUS_KEY, false)) {
                if (DEBUG) Log.d(TAG, "refreshPenMode: Found Xiaomi Pen");
                enablePenMode();
                return;
            }
        }
        if (DEBUG) Log.d(TAG, "refreshPenMode: No Xiaomi Pen found");
        disablePenMode();
    }

    private static boolean isDeviceXiaomiPen(int id) {
        InputDevice inputDevice = mInputManager.getInputDevice(id);
        return inputDevice.getVendorId() == penVendorId &&
                inputDevice.getProductId() == penProductId;
    }

    private static InputDeviceListener mInputDeviceListener = new InputDeviceListener() {
            @Override
            public void onInputDeviceAdded(int id) {
                refreshPenMode();
            }
            @Override
            public void onInputDeviceRemoved(int id) {
                refreshPenMode();
            }
            @Override
            public void onInputDeviceChanged(int id) {
                refreshPenMode();
            }
        };
}
