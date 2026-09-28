/*
    SPDX-FileCopyrightText: 2026 Jona Schmidt
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QRectF>
#include <QRegion>
#include <QVariant>
#include <qqmlregistration.h>

// Rounded QRegion for panelMask, QML can't build one
class DockRegion : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QRectF rect READ rect WRITE setRect NOTIFY rectChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QVariant region READ region NOTIFY regionChanged)

public:
    explicit DockRegion(QObject *parent = nullptr);

    QRectF rect() const;
    void setRect(const QRectF &rect);

    qreal radius() const;
    void setRadius(qreal radius);

    QVariant region() const;

Q_SIGNALS:
    void rectChanged();
    void radiusChanged();
    void regionChanged();

private:
    void updateRegion();
    static QRegion roundedRegion(const QSize &size, qreal radius);

    QRectF m_rect;
    qreal m_radius = 0;
    QRegion m_region;
};
