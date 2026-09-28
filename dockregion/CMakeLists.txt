cmake_minimum_required(VERSION 3.16)

project(dock)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml)
find_package(Plasma REQUIRED)

ecm_add_qml_module(dockplugin URI org.kde.plasma.icontasks2 GENERATE_PLUGIN_SOURCE)
target_sources(dockplugin PRIVATE dockregion.cpp dockregion.h)
target_link_libraries(dockplugin PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
ecm_finalize_qml_module(dockplugin DESTINATION ${KDE_INSTALL_QMLDIR})

plasma_install_package(../plasmoid org.kde.plasma.icontasks2)
