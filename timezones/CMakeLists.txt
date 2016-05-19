

if(UNIX)
add_custom_command(
  OUTPUT tzlib/timezones.c
  COMMAND ${CMAKE_COMMAND} -E make_directory tzlib
  COMMAND CUBRID=${CMAKE_BINARY_DIR} LD_LIBRARY_PATH=${CMAKE_BINARY_DIR}/sa $<TARGET_FILE:cub_admin> gen_tz -i ${CMAKE_CURRENT_SOURCE_DIR}/tzdata -g new
  )
else(UNIX)
  if(TARGET_PLATFORM_BITS EQUAL 32)
    set(REQUIRED_DLLS
	${CMAKE_SOURCE_DIR}/win/external/dll/jansson.dll
	${CMAKE_SOURCE_DIR}/win/external/dll/Win32/libgcrypt.dll
	${CMAKE_SOURCE_DIR}/win/external/dll/Win32/libgpg-error-0.dll
       )
  else(TARGET_PLATFORM_BITS EQUAL 32)
    set(REQUIRED_DLLS
	${CMAKE_SOURCE_DIR}/win/external/dll/jansson64.dll
	${CMAKE_SOURCE_DIR}/win/external/dll/x64/libgcrypt.dll
	${CMAKE_SOURCE_DIR}/win/external/dll/x64/libgpg-error-0.dll
       )
  endif(TARGET_PLATFORM_BITS EQUAL 32)
  # cmake 3.5 or higher version is required for "-E env"(>=3.1) and "-E copy multiple-sources"(>=3.5)
  add_custom_command(
    OUTPUT tzlib/timezones.c
    COMMAND ${CMAKE_COMMAND} -E make_directory tzlib
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:cubridsa> $<TARGET_FILE_DIR:cub_admin>
    COMMAND ${CMAKE_COMMAND} -E copy ${REQUIRED_DLLS} $<TARGET_FILE_DIR:cub_admin>
    COMMAND ${CMAKE_COMMAND} -E env "CUBRID=${CMAKE_BINARY_DIR}" $<TARGET_FILE:cub_admin> gen_tz -i ${CMAKE_CURRENT_SOURCE_DIR}/tzdata -g new
    )
endif(UNIX)
add_custom_target(gen_timezones DEPENDS cubridsa cub_admin tzlib/timezones.c)
set_source_files_properties(tzlib/timezones.c PROPERTIES GENERATED true)

add_library(cubrid_timezones SHARED tzlib/timezones.c)
set_target_properties(cubrid_timezones PROPERTIES SOVERSION "${CUBRID_MAJOR_VERSION}.${CUBRID_MINOR_VERSION}")
if(WIN32)
  set_target_properties(cubrid_timezones PROPERTIES OUTPUT_NAME libcubrid_timezones)
endif(WIN32)
target_include_directories(cubrid_timezones PRIVATE ${CMAKE_SOURCE_DIR}/src/base)
add_dependencies(cubrid_timezones gen_timezones gen_msgs_en_US)

install(TARGETS cubrid_timezones
  RUNTIME DESTINATION ${CUBRID_LIBDIR}
  LIBRARY DESTINATION ${CUBRID_LIBDIR}
  )

if(UNIX)
  install(PROGRAMS
    make_tz.sh
    DESTINATION ${CUBRID_BINDIR})
  install(PROGRAMS
    tzlib/build_tz.sh
    DESTINATION ${CUBRID_TZDIR}/tzlib)
else(UNIX)
  if(TARGET_PLATFORM_BITS EQUAL 32)
    set(MAKE_TZ_SCRIPT make_tz_Win32.bat)
    set(MAKE_TZLIB_DIR tzlib_win_Win32)
  else(TARGET_PLATFORM_BITS EQUAL 32)
    set(MAKE_TZ_SCRIPT make_tz_x64.bat)
    set(MAKE_TZLIB_DIR tzlib_win_x64)
  endif(TARGET_PLATFORM_BITS EQUAL 32)
  install(PROGRAMS
    ${MAKE_TZ_SCRIPT}
    DESTINATION ${CUBRID_BINDIR}
    RENAME make_tz.bat)
  install(FILES
    ${MAKE_TZLIB_DIR}/makefile
    DESTINATION ${CUBRID_TZDIR}/tzlib)
endif(UNIX)

install(DIRECTORY
  tzdata
  DESTINATION ${CUBRID_TZDIR}
  PATTERN "Makefile.am" EXCLUDE)

install(FILES
  ${CMAKE_SOURCE_DIR}/src/base/timezone_lib_common.h
  DESTINATION ${CUBRID_TZDIR}/tzlib)



# install pdb files for debugging on windows
# TODO: move the pdb files to CUBRID/symbols directory
if(WIN32)
  install(DIRECTORY
    ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_BUILD_TYPE}/
    DESTINATION ${CUBRID_BINDIR}
    FILES_MATCHING PATTERN "*.pdb"
    )
endif(WIN32)