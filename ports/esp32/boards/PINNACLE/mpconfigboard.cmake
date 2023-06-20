set(SDKCONFIG_DEFAULTS
    boards/sdkconfig.base
    boards/sdkconfig.ble
    boards/PINNACLE/sdkconfig.board
)
add_compile_definitions(MICROPY_PY_NETWORK_HOSTNAME_MAX_LEN=31)
