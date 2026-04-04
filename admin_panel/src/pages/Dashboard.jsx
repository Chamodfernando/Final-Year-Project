import React from 'react';
import { Users, MapPin, Landmark, TrendingUp } from 'lucide-react';

const Dashboard = () => {
    const stats = [
        { label: 'Total Users', value: '1,284', icon: Users, color: '#3b82f6' },
        { label: 'Total Locations', value: '42', icon: MapPin, color: '#f59e0b' },
        { label: 'Total Artifacts', value: '156', icon: Landmark, color: '#10b981' },
        { label: 'Total Bookings', value: '382', icon: TrendingUp, color: '#8b5cf6' },
    ];

    return (
        <div className="dashboard">
            <div className="stats-grid">
                {stats.map((stat) => (
                    <div key={stat.label} className="card stat-card">
                        <div className="stat-icon" style={{ backgroundColor: `${stat.color}15`, color: stat.color }}>
                            <stat.icon size={24} />
                        </div>
                        <div className="stat-info">
                            <h3 className="stat-value">{stat.value}</h3>
                            <p className="stat-label">{stat.label}</p>
                        </div>
                    </div>
                ))}
            </div>

            <style>{`
        .stats-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
          gap: 24px;
        }

        .stat-card {
          display: flex;
          align-items: center;
          gap: 20px;
          padding: 24px;
        }

        .stat-icon {
          width: 56px;
          height: 56px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .stat-value {
          font-size: 24px;
          font-weight: 700;
          color: var(--text-main);
        }

        .stat-label {
          font-size: 14px;
          color: var(--text-muted);
          font-weight: 500;
        }
      `}</style>
        </div>
    );
};

export default Dashboard;
