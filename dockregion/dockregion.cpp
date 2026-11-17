/*
    SPDX-FileCopyrightText: 2026 Jona Schmidt
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockregion.h"

#include <QBitmap>
#include <QPixmap>
#include <QPainter>
#include <QPainterPath>

DockRegion::DockRegion(QObject *parent)
    : QObject(parent)
{
}

QRectF DockRegion::rect() const
{
    return m_rect;
}

void DockRegion::setRect(const QRectF &rect)
{
    if (m_rect == rect) {
        return;
    }
    m_rect = rect;
    Q_EMIT rectChanged();
    updateRegion();
}

qreal DockRegion::radius() const
{
    return m_radius;
}

void DockRegion::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    updateRegion();
}

QVariant DockRegion::region() const
{
    return QVariant::fromValue(m_region);
}

void DockRegion::updateRegion()
{
    const QRect alignedRect = m_rect.toRect();
    QRegion region;
    if (!alignedRect.isEmpty()) {
        region = roundedRegion(alignedRect.size(), m_radius).translated(alignedRect.topLeft());
    }
    if (region == m_region) {
        return;
    }
    m_region = region;
    Q_EMIT regionChanged();
}

QRegion DockRegion::roundedRegion(const QSize &size, qreal radius)
{
    // Quadratic corners, what the refraction was tuned against
    const QRectF bounds(QPointF(0, 0), size);
    radius = std::min({radius, bounds.width() / 2, bounds.height() / 2});
    QPainterPath path;
    path.moveTo(bounds.topLeft() + QPointF(radius, 0));
    path.lineTo(bounds.topRight() - QPointF(radius, 0));
    path.quadTo(bounds.topRight(), bounds.topRight() + QPointF(0, radius));
    path.lineTo(bounds.bottomRight() - QPointF(0, radius));
    path.quadTo(bounds.bottomRight(), bounds.bottomRight() - QPointF(radius, 0));
    path.lineTo(bounds.bottomLeft() + QPointF(radius, 0));
    path.quadTo(bounds.bottomLeft(), bounds.bottomLeft() - QPointF(0, radius));
    path.lineTo(bounds.topLeft() + QPointF(0, radius));
    path.quadTo(bounds.topLeft(), bounds.topLeft() + QPointF(radius, 0));

    QPixmap pixmap(size);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(Qt::NoPen);
    painter.setBrush(Qt::black);
    painter.drawPath(path);
    painter.end();

    // Keep every antialiased pixel
    return QRegion(pixmap.createMaskFromColor(Qt::transparent));
}
