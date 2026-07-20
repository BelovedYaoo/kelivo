package com.psyche.kelivo;

import android.app.Application;

public final class KelivoApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        // 进程级初始化同时覆盖前台 Activity 与无 Activity 的后台 Flutter Engine。
        KelivoKeystoreBridge.initialize(this);
    }
}
