import React, { useState, useEffect } from 'react';
import { dbService, storageService } from '../services/dbService';
import { Plus, MapPin, Star, Trash2, Edit, X, Image as ImageIcon, Loader2 } from 'lucide-react';

const Locations = () => {
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);

  // Location Modal State
  const [showModal, setShowModal] = useState(false);
  const [currentLocation, setCurrentLocation] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    district: '',
    description: '',
    imagePath: '',
    tags: '',
    rating: 4.8
  });

  // Artifact Modal State
  const [showArtifactModal, setShowArtifactModal] = useState(false);
  const [artifactLocation, setArtifactLocation] = useState(null);
  const [artifactUploading, setArtifactUploading] = useState(false);
  const [artifactImageFile, setArtifactImageFile] = useState(null);
  const [artifactImagePreview, setArtifactImagePreview] = useState(null);
  const [artifactModelFile, setArtifactModelFile] = useState(null);
  const [artifactModelArFile, setArtifactModelArFile] = useState(null);
  const [artifactFormData, setArtifactFormData] = useState({
    title: '',
    timePeriod: '',
    material: '',
    dimensions: '',
    history: '',
    quickFacts: '',
    modelPathArClose: '',
    modelPathArFar: '',
    modelPathArWall: '',
    modelPathArCeiling: ''
  });

  useEffect(() => {
    fetchLocations();
  }, []);

  const fetchLocations = async () => {
    setLoading(true);
    try {
      const data = await dbService.getAll("locations");
      setLocations(data);
    } catch (error) {
      console.error("Error fetching locations:", error);
    } finally {
      setLoading(false);
    }
  };

  // Location Handlers
  const handleOpenModal = (location = null) => {
    setImageFile(null);
    setImagePreview(null);
    if (location) {
      setCurrentLocation(location);
      setFormData({
        title: location.title || '',
        district: location.district || '',
        description: location.description || '',
        imagePath: location.imagePath || '',
        tags: Array.isArray(location.tags) ? location.tags.join(', ') : (location.tags || ''),
        rating: location.rating || 4.8
      });
      setImagePreview(location.imagePath);
    } else {
      setCurrentLocation(null);
      setFormData({
        title: '',
        district: '',
        description: '',
        imagePath: '',
        tags: '',
        rating: 4.8
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

    try {
      if (imageFile) {
        const fileName = `${Date.now()}_${imageFile.name}`;
        finalImagePath = await storageService.uploadFile(imageFile, `locations/${fileName}`);
      }

      const ratingValue = parseFloat(formData.rating);
      const dataToSave = {
        title: formData.title,
        district: formData.district,
        description: formData.description,
        imagePath: finalImagePath,
        tags: String(formData.tags).split(',').map(tag => tag.trim()).filter(tag => tag !== ''),
        rating: isNaN(ratingValue) ? 0 : ratingValue,
        updatedAt: new Date().toISOString()
      };

      if (currentLocation) {
        await dbService.update("locations", currentLocation.id, dataToSave);
      } else {
        await dbService.add("locations", dataToSave);
      }

      setShowModal(false);
      fetchLocations();
    } catch (error) {
      console.error("Error saving location:", error);
      alert("Error saving location: " + error.message);
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this location?")) {
      try {
        await dbService.delete("locations", id);
        fetchLocations();
      } catch (error) {
        alert("Error deleting: " + error.message);
      }
    }
  };

  // Artifact Handlers
  const handleOpenArtifactModal = (location) => {
    setArtifactLocation(location);
    setArtifactImageFile(null);
    setArtifactImagePreview(null);
    setArtifactModelFile(null);
    setArtifactModelArFile(null);
    setArtifactFormData({
      title: '',
      timePeriod: '',
      material: '',
      dimensions: '',
      history: '',
      quickFacts: '',
      modelPathArClose: '',
      modelPathArFar: '',
      modelPathArWall: '',
      modelPathArCeiling: ''
    });
    setShowArtifactModal(true);
  };

  const handleArtifactFileChange = (e, type) => {
    const file = e.target.files[0];
    if (file) {
      if (type === 'image') {
        setArtifactImageFile(file);
        const reader = new FileReader();
        reader.onloadend = () => setArtifactImagePreview(reader.result);
        reader.readAsDataURL(file);
      } else if (type === 'modelAr') {
        setArtifactModelArFile(file);
      } else {
        setArtifactModelFile(file);
      }
    }
  };

  const handleArtifactSubmit = async (e) => {
    e.preventDefault();
    setArtifactUploading(true);

    try {
      let imageUrl = '';
      let modelUrl = '';
      let modelPathAr = '';

      if (artifactImageFile) {
        const fileName = `${Date.now()}_${artifactImageFile.name}`;
        imageUrl = await storageService.uploadFile(artifactImageFile, `artifacts/images/${fileName}`);
      }

      if (artifactModelFile) {
        const fileName = `${Date.now()}_${artifactModelFile.name}`;
        modelUrl = await storageService.uploadFile(artifactModelFile, `artifacts/models/${fileName}`);
      }

      if (artifactModelArFile) {
        const fileName = `${Date.now()}_ar_${artifactModelArFile.name}`;
        modelPathAr = await storageService.uploadFile(artifactModelArFile, `artifacts/models_ar/${fileName}`);
      }

      // 3. Save to Firestore
      const trimUrl = (v) => (typeof v === 'string' ? v.trim() : '');
      const artifactData = {
        title: artifactFormData.title,
        timePeriod: artifactFormData.timePeriod,
        material: artifactFormData.material,
        dimensions: artifactFormData.dimensions,
        history: artifactFormData.history,
        quickFacts: artifactFormData.quickFacts.split(',').map(f => f.trim()).filter(f => f !== ''),
        imagePath: imageUrl,
        modelPath: modelUrl,
        ...(modelPathAr ? { modelPathAr } : {}),
        ...(trimUrl(artifactFormData.modelPathArClose)
          ? { modelPathArClose: trimUrl(artifactFormData.modelPathArClose) }
          : {}),
        ...(trimUrl(artifactFormData.modelPathArFar)
          ? { modelPathArFar: trimUrl(artifactFormData.modelPathArFar) }
          : {}),
        ...(trimUrl(artifactFormData.modelPathArWall)
          ? { modelPathArWall: trimUrl(artifactFormData.modelPathArWall) }
          : {}),
        ...(trimUrl(artifactFormData.modelPathArCeiling)
          ? { modelPathArCeiling: trimUrl(artifactFormData.modelPathArCeiling) }
          : {}),
        locationId: artifactLocation.id,
        siteName: artifactLocation.title,
        createdAt: new Date().toISOString()
      };

      console.log("Saving artifact data:", artifactData);
      await dbService.add("artifacts", artifactData);
      alert("Artifact added successfully!");
      setShowArtifactModal(false);
    } catch (error) {
      console.error("Error adding artifact:", error);
      alert("Failed to add artifact: " + error.message);
    } finally {
      setArtifactUploading(false);
    }
  };

  return (
    <div className="locations-page">
      <div className="page-header-row">
        <p className="page-desc">Manage tourist locations appearing on the mobile dashboard.</p>
        <button className="btn btn-primary" onClick={() => handleOpenModal()}>
          <Plus size={18} />
          <span>Add Location</span>
        </button>
      </div>

      {loading ? (
        <div className="loading-state">Loading locations...</div>
      ) : (
        <div className="locations-grid">
          {locations.map((loc) => (
            <div key={loc.id} className="card location-card">
              <div className="location-img-preview">
                {loc.imagePath ? (
                  <img src={loc.imagePath} alt={loc.title} />
                ) : (
                  <div className="no-img"><MapPin size={24} /></div>
                )}
              </div>
              <div className="location-info">
                <h3 className="location-title">{loc.title}</h3>
                <div className="location-meta">
                  <MapPin size={14} />
                  <span>{loc.district}</span>
                </div>
                <div className="location-rating">
                  <Star size={14} fill="#f59e0b" color="#f59e0b" />
                  <span>{loc.rating}</span>
                </div>
                <div className="tag-list">
                  {loc.tags?.map(tag => (
                    <span key={tag} className="tag">{tag}</span>
                  ))}
                </div>
              </div>
              <div className="card-actions-fixed">
                <button className="btn btn-outline-small" onClick={() => handleOpenArtifactModal(loc)}>
                  <Plus size={14} />
                  <span>Add Artefacts</span>
                </button>
                <div className="flex-spacer"></div>
                <button className="icon-btn-small" onClick={() => handleOpenModal(loc)}><Edit size={16} /></button>
                <button className="icon-btn-small delete" onClick={() => handleDelete(loc.id)}><Trash2 size={16} /></button>
              </div>
            </div>
          ))}
          {locations.length === 0 && <div className="no-data">No locations found.</div>}
        </div>
      )}

      {/* Location Modal */}
      {showModal && (
        <div className="modal-overlay">
          <div className="card modal-content">
            <div className="modal-header">
              <h3>{currentLocation ? 'Edit Location' : 'Add New Location'}</h3>
              <button className="close-btn" onClick={() => setShowModal(false)} disabled={uploading}><X size={20} /></button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="form-group">
                <label className="label">Title</label>
                <input
                  type="text"
                  className="input"
                  required
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="e.g. Sigiriya Rock Fortress"
                />
              </div>

              <div className="form-group">
                <label className="label">Location Image</label>
                <div className="image-upload-wrapper">
                  <div className="preview-box">
                    {imagePreview ? (
                      <img src={imagePreview} alt="Preview" className="preview-img" />
                    ) : (
                      <div className="placeholder">
                        <ImageIcon size={32} />
                        <span>No image selected</span>
                      </div>
                    )}
                  </div>
                  <input
                    type="file"
                    id="loc-image"
                    accept="image/*"
                    onChange={handleImageChange}
                    className="file-input-hidden"
                  />
                  <label htmlFor="loc-image" className="btn btn-outline full-width mt-2">
                    <ImageIcon size={16} />
                    Choose from Device
                  </label>
                </div>
              </div>

              <div className="form-group">
                <label className="label">District & Province</label>
                <input
                  type="text"
                  className="input"
                  required
                  value={formData.district}
                  onChange={(e) => setFormData({ ...formData, district: e.target.value })}
                  placeholder="e.g. Dambulla, Central Province"
                />
              </div>
              <div className="form-group">
                <label className="label">Description / History</label>
                <textarea
                  className="input"
                  required
                  rows="4"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Describe the historical importance..."
                />
              </div>
              <div className="form-group">
                <label className="label">Tags (comma separated)</label>
                <input
                  type="text"
                  className="input"
                  value={formData.tags}
                  onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
                  placeholder="Ancient, UNESCO, Nature"
                />
              </div>
              <div className="form-group">
                <label className="label">Rating</label>
                <input
                  type="number"
                  step="0.1"
                  min="0"
                  max="5"
                  className="input"
                  value={formData.rating}
                  onChange={(e) => setFormData({ ...formData, rating: e.target.value })}
                />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)} disabled={uploading}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={uploading}>
                  {uploading ? <><Loader2 className="animate-spin" size={16} /> Saving...</> : 'Save Location'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Artifact Modal */}
      {showArtifactModal && (
        <div className="modal-overlay">
          <div className="card modal-content wide-modal">
            <div className="modal-header">
              <div>
                <h3>Add Artifact for Site</h3>
                <p className="subtext">{artifactLocation?.title}</p>
              </div>
              <button className="close-btn" onClick={() => setShowArtifactModal(false)} disabled={artifactUploading}><X size={20} /></button>
            </div>
            <form onSubmit={handleArtifactSubmit}>
              <div className="modal-body-grid">
                <div className="column">
                  <div className="form-group">
                    <label className="label">Artifact Title</label>
                    <input
                      type="text"
                      className="input"
                      required
                      value={artifactFormData.title}
                      onChange={(e) => setArtifactFormData({ ...artifactFormData, title: e.target.value })}
                      placeholder="e.g. Ancient Moonstone"
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">Artifact Image</label>
                    <div className="image-upload-wrapper">
                      <div className="preview-box small">
                        {artifactImagePreview ? (
                          <img src={artifactImagePreview} alt="Preview" className="preview-img" />
                        ) : (
                          <div className="placeholder">
                            <ImageIcon size={24} />
                          </div>
                        )}
                      </div>
                      <input
                        type="file"
                        id="art-image"
                        accept="image/*"
                        onChange={(e) => handleArtifactFileChange(e, 'image')}
                        className="file-input-hidden"
                      />
                      <label htmlFor="art-image" className="btn btn-outline full-width mt-2">Choose Image</label>
                    </div>
                  </div>
                  <div className="form-group">
                    <label className="label">3D Model (.glb)</label>
                    <p className="field-help">Full-quality model for the in-app 3D viewer.</p>
                    <input
                      type="file"
                      id="art-model-full"
                      accept=".glb"
                      onChange={(e) => handleArtifactFileChange(e, 'model')}
                      className="input"
                    />
                    {artifactModelFile && <p className="file-name-hint">{artifactModelFile.name}</p>}
                  </div>
                  <div className="form-group">
                    <label className="label">AR model (.glb, lighter) — optional</label>
                    <p className="field-help">Lower-poly / smaller file for ARCore. App uses this in AR when provided.</p>
                    <input
                      type="file"
                      id="art-model-ar"
                      accept=".glb"
                      onChange={(e) => handleArtifactFileChange(e, 'modelAr')}
                      className="input"
                    />
                    {artifactModelArFile && <p className="file-name-hint">{artifactModelArFile.name}</p>}
                  </div>
                </div>

                <div className="column">
                  <div className="form-row">
                    <div className="form-group">
                      <label className="label">Time Period</label>
                      <input
                        type="text"
                        className="input"
                        value={artifactFormData.timePeriod}
                        onChange={(e) => setArtifactFormData({ ...artifactFormData, timePeriod: e.target.value })}
                        placeholder="Anuradhapura Era"
                      />
                    </div>
                    <div className="form-group">
                      <label className="label">Material</label>
                      <input
                        type="text"
                        className="input"
                        value={artifactFormData.material}
                        onChange={(e) => setArtifactFormData({ ...artifactFormData, material: e.target.value })}
                        placeholder="Granite"
                      />
                    </div>
                  </div>
                  <div className="form-group">
                    <label className="label">Dimensions</label>
                    <input
                      type="text"
                      className="input"
                      value={artifactFormData.dimensions}
                      onChange={(e) => setArtifactFormData({ ...artifactFormData, dimensions: e.target.value })}
                      placeholder="e.g. 1.2m x 0.8m"
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">History & Details</label>
                    <textarea
                      className="input"
                      rows="3"
                      value={artifactFormData.history}
                      onChange={(e) => setArtifactFormData({ ...artifactFormData, history: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">Quick Facts (comma separated)</label>
                    <input
                      type="text"
                      className="input"
                      value={artifactFormData.quickFacts}
                      onChange={(e) => setArtifactFormData({ ...artifactFormData, quickFacts: e.target.value })}
                      placeholder="e.g. 500 BC, Hand-carved, Sacred"
                    />
                  </div>
                  <p className="field-help">
                    Optional contextual AR models (URLs only). Upload the main AR .glb on the left; add hosted URLs here
                    for close / far / wall / ceiling variants if you have them.
                  </p>
                  <div className="form-group">
                    <label className="label">AR close (.glb URL)</label>
                    <input
                      type="url"
                      className="input"
                      value={artifactFormData.modelPathArClose}
                      onChange={(e) =>
                        setArtifactFormData({ ...artifactFormData, modelPathArClose: e.target.value })
                      }
                      placeholder="https://…"
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">AR far (.glb URL)</label>
                    <input
                      type="url"
                      className="input"
                      value={artifactFormData.modelPathArFar}
                      onChange={(e) =>
                        setArtifactFormData({ ...artifactFormData, modelPathArFar: e.target.value })
                      }
                      placeholder="https://…"
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">AR wall (.glb URL)</label>
                    <input
                      type="url"
                      className="input"
                      value={artifactFormData.modelPathArWall}
                      onChange={(e) =>
                        setArtifactFormData({ ...artifactFormData, modelPathArWall: e.target.value })
                      }
                      placeholder="https://…"
                    />
                  </div>
                  <div className="form-group">
                    <label className="label">AR ceiling (.glb URL)</label>
                    <input
                      type="url"
                      className="input"
                      value={artifactFormData.modelPathArCeiling}
                      onChange={(e) =>
                        setArtifactFormData({ ...artifactFormData, modelPathArCeiling: e.target.value })
                      }
                      placeholder="https://…"
                    />
                  </div>
                </div>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn btn-outline" onClick={() => setShowArtifactModal(false)} disabled={artifactUploading}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={artifactUploading}>
                  {artifactUploading ? <><Loader2 className="animate-spin" size={16} /> Uploading...</> : 'Save Artifact'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <style>{`
        .loading-state { text-align: center; padding: 40px; color: var(--text-muted); }
        .no-data { text-align: center; padding: 20px; color: var(--text-muted); grid-column: 1 / -1; }
        .page-header-row { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 32px; }
        .locations-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 24px; }
        .location-card { display: flex; flex-direction: column; overflow: hidden; padding: 0; }
        .location-img-preview { height: 160px; background: #f1f5f9; position: relative; }
        .location-img-preview img { width: 100%; height: 100%; object-fit: cover; }
        .no-img { display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-muted); }
        .location-info { padding: 20px; flex: 1; }
        .location-title { font-size: 18px; font-weight: 700; margin-bottom: 8px; }
        .location-meta, .location-rating { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-muted); margin-bottom: 6px; }
        .tag-list { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
        .tag { padding: 4px 10px; background: #ecfdf5; border-radius: 6px; font-size: 11px; font-weight: 700; color: var(--primary); }
        .card-actions-fixed { padding: 12px 20px; border-top: 1px solid var(--border); display: flex; justify-content: flex-end; gap: 12px; }
        
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .close-btn { background: none; border: none; color: var(--text-muted); cursor: pointer; }
        textarea.input { resize: vertical; margin-top: 8px; }

        .image-upload-wrapper { margin-top: 8px; }
        .preview-box { height: 140px; background: #f8fafc; border: 2px dashed var(--border); border-radius: 12px; overflow: hidden; display: flex; align-items: center; justify-content: center; }
        .preview-img { width: 100%; height: 100%; object-fit: cover; }
        .placeholder { display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; }
        .file-input-hidden { display: none; }
        .animate-spin { animation: spin 1s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .mt-2 { margin-top: 8px; }
        .full-width { width: 100%; justify-content: center; }
        .flex-spacer { flex: 1; }
        .btn-outline-small { 
          padding: 6px 12px; 
          border: 1px solid var(--primary); 
          color: var(--primary); 
          background: none; 
          border-radius: 6px; 
          font-size: 12px; 
          font-weight: 600; 
          display: flex; 
          align-items: center; 
          gap: 6px; 
          cursor: pointer;
        }
        .btn-outline-small:hover { background: #f0fdf4; }
        
        .wide-modal { max-width: 800px; width: 95%; }
        .subtext { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
        .modal-body-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px; }
        .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .preview-box.small { height: 100px; }
        .file-name-hint { font-size: 11px; color: var(--primary); margin-top: 4px; }
        .field-help { font-size: 12px; color: var(--text-muted); margin: 0 0 6px 0; line-height: 1.35; }
      `}</style>
    </div>
  );
};

export default Locations;
