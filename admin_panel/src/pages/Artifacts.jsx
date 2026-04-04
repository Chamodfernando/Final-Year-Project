import React, { useState, useEffect } from 'react';
import { dbService, storageService } from '../services/dbService';
import { Plus, Box, Landmark, Trash2, Edit, X, Image as ImageIcon, Loader2 } from 'lucide-react';

const Artifacts = () => {
    const [artifacts, setArtifacts] = useState([]);
    const [locations, setLocations] = useState([]);
    const [showModal, setShowModal] = useState(false);
    const [currentArtifact, setCurrentArtifact] = useState(null);
    const [loading, setLoading] = useState(true);
    const [uploading, setUploading] = useState(false);
    const [imageFile, setImageFile] = useState(null);
    const [imagePreview, setImagePreview] = useState(null);

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
        modelPath: ''
    });

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const artData = await dbService.getAll("artifacts");
            const locData = await dbService.getAll("locations");
            setArtifacts(artData);
            setLocations(locData);
        } catch (error) {
            console.error("Error fetching data:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleOpenModal = (art = null) => {
        setImageFile(null);
        setImagePreview(null);
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
                quickFacts: Array.isArray(art.quickFacts) ? art.quickFacts.join('\n') : (art.quickFacts || ''),
                modelPath: art.modelPath || ''
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
                modelPath: ''
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
        console.log("Artifact submit started...");
        setUploading(true);

        let finalImagePath = formData.imagePath;

        try {
            if (imageFile) {
                console.log("Uploading artifact image:", imageFile.name);
                try {
                    const fileName = `${Date.now()}_artifact_${imageFile.name}`;
                    const path = `artifacts/${fileName}`;
                    finalImagePath = await storageService.uploadFile(imageFile, path);
                    console.log("Upload success, URL:", finalImagePath);
                } catch (uploadError) {
                    console.error("Artifact image upload failed:", uploadError);
                    throw new Error("Failed to upload artifact image: " + uploadError.message);
                }
            }

            console.log("Preparing artifact data...");
            const dataToSave = {
                title: formData.title,
                siteName: formData.siteName,
                locationId: formData.locationId,
                imagePath: finalImagePath,
                timePeriod: formData.timePeriod,
                material: formData.material,
                dimensions: formData.dimensions,
                history: formData.history,
                quickFacts: String(formData.quickFacts).split('\n').map(f => f.trim()).filter(f => f !== ''),
                modelPath: formData.modelPath,
                updatedAt: new Date().toISOString()
            };
            console.log("Artifact data to save:", dataToSave);

            if (currentArtifact) {
                console.log("Updating artifact:", currentArtifact.id);
                await dbService.update("artifacts", currentArtifact.id, dataToSave);
            } else {
                console.log("Adding new artifact to 'artifacts'...");
                await dbService.add("artifacts", dataToSave);
            }

            console.log("Artifact save successful!");
            setShowModal(false);
            fetchData();
        } catch (error) {
            console.error("Error in artifact handleSubmit:", error);
            alert("Error saving artifact: " + error.message);
        } finally {
            setUploading(false);
            console.log("Artifact submit process finished.");
        }
    };

    const handleDelete = async (id) => {
        if (window.confirm("Delete this artifact?")) {
            try {
                await dbService.delete("artifacts", id);
                fetchData();
            } catch (error) {
                alert("Error deleting: " + error.message);
            }
        }
    };

    return (
        <div className="artifacts-page">
            <div className="page-header-row">
                <p className="page-desc">Manage ancient artifacts and link them to locations.</p>
                <button className="btn btn-primary" onClick={() => handleOpenModal()}>
                    <Plus size={18} />
                    <span>Add Artifact</span>
                </button>
            </div>

            {loading ? (
                <div className="loading-state">Loading artifacts...</div>
            ) : (
                <div className="table-container card">
                    <table>
                        <thead>
                            <tr>
                                <th>Artifact</th>
                                <th>Location Site</th>
                                <th>3D Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {artifacts.map((art) => (
                                <tr key={art.id}>
                                    <td>
                                        <div className="art-cell">
                                            {art.imagePath ? (
                                                <img src={art.imagePath} className="art-thumb" alt="" />
                                            ) : (
                                                <div className="art-thumb-placeholder"><ImageIcon size={16} /></div>
                                            )}
                                            <span className="font-600">{art.title}</span>
                                        </div>
                                    </td>
                                    <td>{art.siteName}</td>
                                    <td>
                                        {art.modelPath ? (
                                            <div className="badge badge-success"><Box size={14} /><span>GLB Linked</span></div>
                                        ) : (
                                            <span className="text-muted">No Model</span>
                                        )}
                                    </td>
                                    <td>
                                        <div className="actions">
                                            <button className="icon-btn-small" onClick={() => handleOpenModal(art)}><Edit size={16} /></button>
                                            <button className="icon-btn-small delete" onClick={() => handleDelete(art.id)}><Trash2 size={16} /></button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                            {artifacts.length === 0 && (
                                <tr>
                                    <td colSpan="4" style={{ textAlign: 'center', padding: '20px', color: 'var(--text-muted)' }}>
                                        No artifacts found.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            )}

            {showModal && (
                <div className="modal-overlay">
                    <div className="card modal-content wide-modal">
                        <div className="modal-header">
                            <h3>{currentArtifact ? 'Edit Artifact' : 'Add New Artifact'}</h3>
                            <button className="close-btn" onClick={() => setShowModal(false)} disabled={uploading}><X size={20} /></button>
                        </div>
                        <form onSubmit={handleSubmit} className="modal-grid">
                            <div className="form-col">
                                <div className="form-group">
                                    <label className="label">Title</label>
                                    <input className="input" required value={formData.title} onChange={e => setFormData({ ...formData, title: e.target.value })} />
                                </div>

                                <div className="form-group">
                                    <label className="label">Artifact Image</label>
                                    <div className="image-upload-wrapper">
                                        <div className="preview-box compact">
                                            {imagePreview ? (
                                                <img src={imagePreview} alt="Preview" className="preview-img" />
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
                                    <input className="input" required value={formData.siteName} onChange={e => setFormData({ ...formData, siteName: e.target.value })} />
                                </div>
                                <div className="form-group">
                                    <label className="label">Linked Location</label>
                                    <select className="input" required value={formData.locationId} onChange={e => setFormData({ ...formData, locationId: e.target.value })}>
                                        <option value="">Select a location...</option>
                                        {locations.map(loc => (
                                            <option key={loc.id} value={loc.id}>{loc.title}</option>
                                        ))}
                                    </select>
                                </div>
                            </div>
                            <div className="form-col">
                                <div className="form-group">
                                    <label className="label">History</label>
                                    <textarea className="input" rows="4" value={formData.history} onChange={e => setFormData({ ...formData, history: e.target.value })} />
                                </div>
                                <div className="form-group">
                                    <label className="label">Quick Facts (one per line)</label>
                                    <textarea className="input" rows="4" value={formData.quickFacts} onChange={e => setFormData({ ...formData, quickFacts: e.target.value })} />
                                </div>
                                <div className="form-group">
                                    <label className="label">3D Model URL (.glb)</label>
                                    <input className="input" value={formData.modelPath} onChange={e => setFormData({ ...formData, modelPath: e.target.value })} />
                                </div>
                            </div>
                            <div className="modal-footer full-width">
                                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)} disabled={uploading}>Cancel</button>
                                <button type="submit" className="btn btn-primary" disabled={uploading}>
                                    {uploading ? <><Loader2 className="animate-spin" size={16} /> Saving...</> : 'Save Artifact'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            <style>{`
        .loading-state { text-align: center; padding: 40px; color: var(--text-muted); }
        .art-cell { display: flex; align-items: center; gap: 12px; }
        .art-thumb { width: 40px; height: 40px; border-radius: 6px; object-fit: cover; background: #eee; }
        .art-thumb-placeholder { width: 40px; height: 40px; border-radius: 6px; background: #f1f5f9; display: flex; align-items: center; justify-content: center; color: var(--text-muted); }
        .wide-modal { max-width: 800px; width: 90%; }
        .modal-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 12px; }
        .full-width { grid-column: span 2; display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; }
        .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: 700; }
        .badge-success { background: #ecfdf5; color: var(--primary); }

        .image-upload-wrapper { margin-top: 4px; }
        .preview-box.compact { height: 100px; }
        .preview-box { background: #f8fafc; border: 2px dashed var(--border); border-radius: 8px; overflow: hidden; display: flex; align-items: center; justify-content: center; }
        .preview-img { width: 100%; height: 100%; object-fit: cover; }
        .placeholder { display: flex; flex-direction: column; align-items: center; gap: 4px; color: var(--text-muted); font-size: 11px; }
        .file-input-hidden { display: none; }
        .animate-spin { animation: spin 1s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .mt-1 { margin-top: 4px; }
      `}</style>
        </div>
    );
};

export default Artifacts;
