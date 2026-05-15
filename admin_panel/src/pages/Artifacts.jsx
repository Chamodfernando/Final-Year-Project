import React, { useState, useEffect, useMemo } from 'react';
import { dbService, storageService } from '../services/dbService';
import { Plus, Box, Trash2, Edit, X, Image as ImageIcon, Loader2, Search } from 'lucide-react';
import { AnimatedModal } from '../components/AnimatedModal';

const Artifacts = () => {
    const [artifacts, setArtifacts] = useState([]);
    const [locations, setLocations] = useState([]);
    const [showModal, setShowModal] = useState(false);
    const [currentArtifact, setCurrentArtifact] = useState(null);
    const [loading, setLoading] = useState(true);
    const [uploading, setUploading] = useState(false);
    const [imageFile, setImageFile] = useState(null);
    const [imagePreview, setImagePreview] = useState(null);
    const [modelFile, setModelFile] = useState(null);
    const [modelArFile, setModelArFile] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const [formData, setFormData] = useState({
        title: '',
        siteName: '',
        locationId: '',
        imagePath: '',
        timePeriod: '',
        material: '',
        dimensions: '',
        history: '',
        quickFacts: '',
        modelPath: '',
        modelPathAr: '',
        modelPathArClose: '',
        modelPathArFar: '',
        modelPathArWall: '',
        modelPathArCeiling: ''
    });

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const artData = await dbService.getAll('artifacts');
            const locData = await dbService.getAll('locations');
            setArtifacts(artData);
            setLocations(locData);
        } catch (error) {
            console.error('Error fetching data:', error);
        } finally {
            setLoading(false);
        }
    };

    const filteredArtifacts = useMemo(() => {
        const q = searchQuery.trim().toLowerCase();
        if (!q) return artifacts;
        return artifacts.filter((art) => {
            const title = (art.title || '').toLowerCase();
            const site = (art.siteName || '').toLowerCase();
            const period = (art.timePeriod || '').toLowerCase();
            return title.includes(q) || site.includes(q) || period.includes(q);
        });
    }, [artifacts, searchQuery]);

    const handleOpenModal = (art = null) => {
        setImageFile(null);
        setImagePreview(null);
        setModelFile(null);
        setModelArFile(null);
        if (art) {
            setCurrentArtifact(art);
            setFormData({
                title: art.title || '',
                siteName: art.siteName || '',
                locationId: art.locationId || '',
                imagePath: art.imagePath || '',
                timePeriod: art.timePeriod || '',
                material: art.material || '',
                dimensions: art.dimensions || '',
                history: art.history || '',
                quickFacts: Array.isArray(art.quickFacts)
                    ? art.quickFacts.join('\n')
                    : art.quickFacts || '',
                modelPath: art.modelPath || '',
                modelPathAr: art.modelPathAr || '',
                modelPathArClose: art.modelPathArClose || '',
                modelPathArFar: art.modelPathArFar || '',
                modelPathArWall: art.modelPathArWall || '',
                modelPathArCeiling: art.modelPathArCeiling || ''
            });
            setImagePreview(art.imagePath);
        } else {
            setCurrentArtifact(null);
            setFormData({
                title: '',
                siteName: '',
                locationId: '',
                imagePath: '',
                timePeriod: '',
                material: '',
                dimensions: '',
                history: '',
                quickFacts: '',
                modelPath: '',
                modelPathAr: '',
                modelPathArClose: '',
                modelPathArFar: '',
                modelPathArWall: '',
                modelPathArCeiling: ''
            });
        }
        setShowModal(true);
    };

    const handleImageChange = (e) => {
        const file = e.target.files[0];
        if (file) {
            setImageFile(file);
            const reader = new FileReader();
            reader.onloadend = () => {
                setImagePreview(reader.result);
            };
            reader.readAsDataURL(file);
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setUploading(true);

        let finalImagePath = formData.imagePath;
        let finalModelPath = formData.modelPath;
        let finalModelPathAr = formData.modelPathAr?.trim() || '';

        try {
            if (!formData.locationId || !String(formData.locationId).trim()) {
                alert('Please select a linked location — artifacts only appear under that site when location matches.');
                setUploading(false);
                return;
            }

            if (imageFile) {
                const fileName = `${Date.now()}_artifact_${imageFile.name}`;
                finalImagePath = await storageService.uploadFile(
                    imageFile,
                    `artifacts/images/${fileName}`
                );
            }

            if (modelFile) {
                const fileName = `${Date.now()}_${modelFile.name}`;
                finalModelPath = await storageService.uploadFile(
                    modelFile,
                    `artifacts/models/${fileName}`
                );
            }

            if (modelArFile) {
                const fileName = `${Date.now()}_ar_${modelArFile.name}`;
                finalModelPathAr = await storageService.uploadFile(
                    modelArFile,
                    `artifacts/models_ar/${fileName}`
                );
            }

            const dataToSave = {
                title: formData.title,
                siteName: formData.siteName,
                locationId: String(formData.locationId).trim(),
                imagePath: finalImagePath,
                timePeriod: formData.timePeriod,
                material: formData.material,
                dimensions: formData.dimensions,
                history: formData.history,
                quickFacts: String(formData.quickFacts)
                    .split('\n')
                    .map((f) => f.trim())
                    .filter((f) => f !== ''),
                modelPath: finalModelPath,
                modelPathAr: finalModelPathAr || null,
                modelPathArClose: formData.modelPathArClose?.trim() || null,
                modelPathArFar: formData.modelPathArFar?.trim() || null,
                modelPathArWall: formData.modelPathArWall?.trim() || null,
                modelPathArCeiling: formData.modelPathArCeiling?.trim() || null,
                updatedAt: new Date().toISOString()
            };

            if (currentArtifact) {
                await dbService.update('artifacts', currentArtifact.id, dataToSave);
            } else {
                await dbService.add('artifacts', {
                    ...dataToSave,
                    createdAt: new Date().toISOString()
                });
            }

            setShowModal(false);
            fetchData();
        } catch (error) {
            console.error('Error saving artifact:', error);
            alert('Error saving artifact: ' + error.message);
        } finally {
            setUploading(false);
        }
    };

    const handleDelete = async (id) => {
        if (window.confirm('Delete this artifact? This cannot be undone.')) {
            try {
                await dbService.delete('artifacts', id);
                fetchData();
            } catch (error) {
                alert('Error deleting: ' + error.message);
            }
        }
    };

    return (
        <div className="artifacts-page">
            <div className="page-header-row">
                <p className="page-desc">
                    View all artifacts, edit details, or delete entries. Upload GLB files or paste URLs.
                </p>
                <button className="btn btn-primary" type="button" onClick={() => handleOpenModal()}>
                    <Plus size={18} />
                    <span>Add Artifact</span>
                </button>
            </div>

            <div className="artifacts-toolbar card">
                <div className="search-wrap">
                    <Search size={18} className="search-lead-icon" />
                    <input
                        type="search"
                        className="input artifacts-search"
                        placeholder="Search by title, site, or period…"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
                <span className="count-badge">{filteredArtifacts.length} shown</span>
            </div>

            {loading ? (
                <div className="loading-state">Loading artifacts...</div>
            ) : (
                <div className="table-container card">
                    <table>
                        <thead>
                            <tr>
                                <th>Artifact</th>
                                <th>Site</th>
                                <th>Period</th>
                                <th>Viewer GLB</th>
                                <th>AR GLB</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filteredArtifacts.map((art) => (
                                <tr key={art.id}>
                                    <td>
                                        <div className="art-cell">
                                            {art.imagePath ? (
                                                <img src={art.imagePath} className="art-thumb" alt="" />
                                            ) : (
                                                <div className="art-thumb-placeholder">
                                                    <ImageIcon size={16} />
                                                </div>
                                            )}
                                            <span className="font-600">{art.title}</span>
                                        </div>
                                    </td>
                                    <td>{art.siteName || '—'}</td>
                                    <td>{art.timePeriod || '—'}</td>
                                    <td>
                                        {art.modelPath ? (
                                            <div className="badge badge-success">
                                                <Box size={14} />
                                                <span>Yes</span>
                                            </div>
                                        ) : (
                                            <span className="text-muted">No</span>
                                        )}
                                    </td>
                                    <td>
                                        {art.modelPathAr ? (
                                            <div className="badge badge-ar">
                                                <Box size={14} />
                                                <span>Yes</span>
                                            </div>
                                        ) : (
                                            <span className="text-muted">—</span>
                                        )}
                                    </td>
                                    <td>
                                        <div className="artifact-actions">
                                            <button
                                                type="button"
                                                className="icon-btn-small"
                                                title="Edit"
                                                onClick={() => handleOpenModal(art)}
                                            >
                                                <Edit size={16} />
                                            </button>
                                            <button
                                                type="button"
                                                className="icon-btn-small delete"
                                                title="Delete"
                                                onClick={() => handleDelete(art.id)}
                                            >
                                                <Trash2 size={16} />
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                            {filteredArtifacts.length === 0 && (
                                <tr>
                                    <td
                                        colSpan="6"
                                        style={{
                                            textAlign: 'center',
                                            padding: '28px',
                                            color: 'var(--text-muted)'
                                        }}
                                    >
                                        {artifacts.length === 0
                                            ? 'No artifacts yet. Add one or create from Locations.'
                                            : 'No matches for your search.'}
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            )}

            <AnimatedModal
                open={showModal}
                onClose={() => {
                    if (!uploading) setShowModal(false);
                }}
                closeOnBackdrop={!uploading}
                closeOnEscape={!uploading}
                panelClassName="card modal-content wide-modal"
                ariaLabel={currentArtifact ? 'Edit artifact' : 'Add artifact'}
            >
                        <div className="modal-header">
                            <h3>{currentArtifact ? 'Edit Artifact' : 'Add New Artifact'}</h3>
                            <button
                                type="button"
                                className="close-btn"
                                onClick={() => setShowModal(false)}
                                disabled={uploading}
                            >
                                <X size={20} />
                            </button>
                        </div>
                        <form onSubmit={handleSubmit} className="modal-grid">
                            <div className="form-col">
                                <div className="form-group">
                                    <label className="label">Title</label>
                                    <input
                                        className="input"
                                        required
                                        value={formData.title}
                                        onChange={(e) =>
                                            setFormData({ ...formData, title: e.target.value })
                                        }
                                    />
                                </div>

                                <div className="form-group">
                                    <label className="label">Artifact Image</label>
                                    <div className="image-upload-wrapper">
                                        <div className="preview-box compact">
                                            {imagePreview ? (
                                                <img src={imagePreview} alt="" className="preview-img" />
                                            ) : (
                                                <div className="placeholder">
                                                    <ImageIcon size={24} />
                                                    <span>No image</span>
                                                </div>
                                            )}
                                        </div>
                                        <input
                                            type="file"
                                            id="art-image"
                                            accept="image/*"
                                            onChange={handleImageChange}
                                            className="file-input-hidden"
                                        />
                                        <label htmlFor="art-image" className="btn btn-outline full-width mt-1">
                                            <ImageIcon size={14} />
                                            Choose Image
                                        </label>
                                    </div>
                                </div>

                                <div className="form-group">
                                    <label className="label">Site Name</label>
                                    <input
                                        className="input"
                                        required
                                        value={formData.siteName}
                                        onChange={(e) =>
                                            setFormData({ ...formData, siteName: e.target.value })
                                        }
                                    />
                                </div>
                                <div className="form-group">
                                    <label className="label">Linked Location</label>
                                    <select
                                        className="input"
                                        required
                                        value={formData.locationId}
                                        onChange={(e) =>
                                            setFormData({ ...formData, locationId: e.target.value })
                                        }
                                    >
                                        <option value="">Select a location...</option>
                                        {locations.map((loc) => (
                                            <option key={loc.id} value={loc.id}>
                                                {loc.title}
                                            </option>
                                        ))}
                                    </select>
                                </div>

                                <div className="form-row">
                                    <div className="form-group">
                                        <label className="label">Time Period</label>
                                        <input
                                            className="input"
                                            value={formData.timePeriod}
                                            onChange={(e) =>
                                                setFormData({ ...formData, timePeriod: e.target.value })
                                            }
                                            placeholder="e.g. Kandyan period"
                                        />
                                    </div>
                                    <div className="form-group">
                                        <label className="label">Material</label>
                                        <input
                                            className="input"
                                            value={formData.material}
                                            onChange={(e) =>
                                                setFormData({ ...formData, material: e.target.value })
                                            }
                                        />
                                    </div>
                                </div>
                                <div className="form-group">
                                    <label className="label">Dimensions</label>
                                    <input
                                        className="input"
                                        value={formData.dimensions}
                                        onChange={(e) =>
                                            setFormData({ ...formData, dimensions: e.target.value })
                                        }
                                        placeholder="e.g. 1.2m × 0.8m"
                                    />
                                </div>
                            </div>
                            <div className="form-col">
                                <div className="form-group">
                                    <label className="label">History</label>
                                    <textarea
                                        className="input"
                                        rows="4"
                                        value={formData.history}
                                        onChange={(e) =>
                                            setFormData({ ...formData, history: e.target.value })
                                        }
                                    />
                                </div>
                                <div className="form-group">
                                    <label className="label">Quick Facts (one per line)</label>
                                    <textarea
                                        className="input"
                                        rows="4"
                                        value={formData.quickFacts}
                                        onChange={(e) =>
                                            setFormData({ ...formData, quickFacts: e.target.value })
                                        }
                                    />
                                </div>
                                <div className="form-group">
                                    <label className="label">3D Model URL (.glb)</label>
                                    <input
                                        className="input"
                                        value={formData.modelPath}
                                        onChange={(e) =>
                                            setFormData({ ...formData, modelPath: e.target.value })
                                        }
                                        placeholder="https://… or leave empty if uploading below"
                                    />
                                    <p className="field-help">
                                        Optional file replaces URL on save.
                                    </p>
                                    <input
                                        type="file"
                                        accept=".glb"
                                        onChange={(e) =>
                                            setModelFile(e.target.files?.[0] || null)
                                        }
                                        className="input"
                                    />
                                    {modelFile && (
                                        <p className="file-name-hint">{modelFile.name}</p>
                                    )}
                                </div>
                                <div className="form-group">
                                    <label className="label">AR model URL (lighter .glb)</label>
                                    <input
                                        className="input"
                                        value={formData.modelPathAr}
                                        onChange={(e) =>
                                            setFormData({ ...formData, modelPathAr: e.target.value })
                                        }
                                        placeholder="Optional — lighter model for ARCore"
                                    />
                                    <input
                                        type="file"
                                        accept=".glb"
                                        onChange={(e) =>
                                            setModelArFile(e.target.files?.[0] || null)
                                        }
                                        className="input"
                                    />
                                    {modelArFile && (
                                        <p className="file-name-hint">{modelArFile.name}</p>
                                    )}
                                    <p className="field-help" style={{ marginTop: '10px' }}>
                                        Optional contextual AR models (URLs only). If empty, the app falls back to the
                                        primary AR model above. Close ≈ under 0.55 m from camera; far ≈ 1.8 m+.
                                    </p>
                                    <label className="label" style={{ marginTop: '8px' }}>
                                        AR close (.glb URL)
                                    </label>
                                    <input
                                        className="input"
                                        value={formData.modelPathArClose}
                                        onChange={(e) =>
                                            setFormData({
                                                ...formData,
                                                modelPathArClose: e.target.value
                                            })
                                        }
                                        placeholder="https://…"
                                    />
                                    <label className="label" style={{ marginTop: '8px' }}>
                                        AR far (.glb URL)
                                    </label>
                                    <input
                                        className="input"
                                        value={formData.modelPathArFar}
                                        onChange={(e) =>
                                            setFormData({
                                                ...formData,
                                                modelPathArFar: e.target.value
                                            })
                                        }
                                        placeholder="https://…"
                                    />
                                    <label className="label" style={{ marginTop: '8px' }}>
                                        AR wall (.glb URL)
                                    </label>
                                    <input
                                        className="input"
                                        value={formData.modelPathArWall}
                                        onChange={(e) =>
                                            setFormData({
                                                ...formData,
                                                modelPathArWall: e.target.value
                                            })
                                        }
                                        placeholder="https://…"
                                    />
                                    <label className="label" style={{ marginTop: '8px' }}>
                                        AR ceiling (.glb URL)
                                    </label>
                                    <input
                                        className="input"
                                        value={formData.modelPathArCeiling}
                                        onChange={(e) =>
                                            setFormData({
                                                ...formData,
                                                modelPathArCeiling: e.target.value
                                            })
                                        }
                                        placeholder="https://…"
                                    />
                                </div>
                            </div>
                            <div className="modal-footer full-width">
                                <button
                                    type="button"
                                    className="btn btn-outline"
                                    onClick={() => setShowModal(false)}
                                    disabled={uploading}
                                >
                                    Cancel
                                </button>
                                <button type="submit" className="btn btn-primary" disabled={uploading}>
                                    {uploading ? (
                                        <>
                                            <Loader2 className="animate-spin" size={16} /> Saving...
                                        </>
                                    ) : (
                                        'Save Artifact'
                                    )}
                                </button>
                            </div>
                        </form>
            </AnimatedModal>

            <style>{`
        .page-header-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; flex-wrap: wrap; margin-bottom: 20px; }
        .artifacts-toolbar {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          margin-bottom: 20px;
          padding: 16px 20px;
        }
        .search-wrap {
          display: flex;
          align-items: center;
          gap: 10px;
          flex: 1;
          min-width: 200px;
          max-width: 480px;
        }
        .search-lead-icon { color: var(--text-muted); flex-shrink: 0; }
        .artifacts-search { margin-top: 0 !important; }
        .count-badge { font-size: 13px; color: var(--text-muted); font-weight: 600; }
        .loading-state { text-align: center; padding: 40px; color: var(--text-muted); }
        .text-muted { color: var(--text-muted); }
        .font-600 { font-weight: 600; }
        .art-cell { display: flex; align-items: center; gap: 12px; }
        .art-thumb { width: 40px; height: 40px; border-radius: 6px; object-fit: cover; background: #eee; }
        .art-thumb-placeholder { width: 40px; height: 40px; border-radius: 6px; background: #f1f5f9; display: flex; align-items: center; justify-content: center; color: var(--text-muted); }
        .wide-modal { max-width: 880px; width: 92%; max-height: 92vh; overflow-y: auto; }
        .modal-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 12px; }
        .full-width { grid-column: span 2; display: flex; justify-content: flex-end; gap: 12px; margin-top: 8px; }
        .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: 700; }
        .badge-success { background: #ecfdf5; color: var(--primary); }
        .badge-ar { background: #eff6ff; color: #2563eb; }
        .artifact-actions { display: flex; align-items: center; gap: 8px; }
        .icon-btn-small {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 36px;
          height: 36px;
          border-radius: 8px;
          border: 1px solid var(--border);
          background: white;
          cursor: pointer;
          color: var(--text-main);
        }
        .icon-btn-small:hover { background: #f8fafc; }
        .icon-btn-small.delete { border-color: #fecaca; color: var(--danger); }
        .icon-btn-small.delete:hover { background: #fef2f2; }

        .image-upload-wrapper { margin-top: 4px; }
        .preview-box.compact { height: 100px; }
        .preview-box { background: #f8fafc; border: 2px dashed var(--border); border-radius: 8px; overflow: hidden; display: flex; align-items: center; justify-content: center; }
        .preview-img { width: 100%; height: 100%; object-fit: cover; }
        .placeholder { display: flex; flex-direction: column; align-items: center; gap: 4px; color: var(--text-muted); font-size: 11px; }
        .file-input-hidden { display: none; }
        .animate-spin { animation: spin 1s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .mt-1 { margin-top: 4px; }
        .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
        .close-btn { background: none; border: none; cursor: pointer; color: var(--text-muted); padding: 4px; }
        .field-help { font-size: 12px; color: var(--text-muted); margin: 4px 0 8px 0; }
        .file-name-hint { font-size: 11px; color: var(--primary); margin-top: 4px; }
      `}</style>
        </div>
    );
};

export default Artifacts;
